module Utilrb
    begin
        require 'roby/graph'
        has_roby_graph = true
    rescue LoadError
        has_roby_graph = false
    end

    if has_roby_graph
    class RubyObjectGraph
        attr_reader :graph
        attr_reader :references

        def self.snapshot
            # Doing any Ruby code that do not modify the heap is impossible. List
            # all existing objects once, and only then do the processing.
            # +live_objects+ will be referenced in itself, but we are going to
            # remove it later
            GC.disable
            live_objects = []
            ObjectSpace.each_object do |obj|
                if obj != live_objects
                    live_objects << obj
                end
            end
            GC.enable
        end

        def initialize
            @graph = BGL::Graph.new
            @references = Hash.new
        end

        class ObjectRef
            attr_reader :obj
            def initialize(obj)
                @obj = obj
            end
            include BGL::Vertex
        end

        def test_and_add_reference(obj_ref, var, desc)
            var_ref = references[var.object_id]
            if graph.include?(var_ref)
                add_reference(obj_ref, var_ref, desc)
            end
        end

        def add_reference(obj_ref, var_ref, desc)
            if graph.linked?(obj_ref, var_ref)
                obj_ref[var_ref, graph] << desc
            else
                graph.link(obj_ref, var_ref, [desc].to_set)
            end
        end

        def register_references_to(klass, orig_options = Hash.new)
            options = Kernel.validate_options orig_options,
                :roots => nil
            roots = options[:roots]

            live_objects = RubyObjectGraph.snapshot

            # Create a single ObjectRef per (interesting) live object, so that we
            # can use a BGL::Graph to represent the reference graph.  This will be
            # what we are going to access later on. Use object IDs since we really
            # want to refer to objects and not use eql? comparisons
            desired_seeds = []
            excludes = [live_objects, self, orig_options, options, roots].to_value_set
            live_objects.delete_if do |obj|
                if excludes.include?(obj)
                    true
                else
                    references[obj.object_id] ||= ObjectRef.new(obj)
                    if obj.kind_of?(klass)
                        desired_seeds << obj.object_id
                    end
                    false
                end
            end

            desired_seeds.each do |obj_id|
                graph.insert(references[obj_id])
            end
            ignored_enumeration = Hash.new

            loop do
                old_graph_size = graph.size
                live_objects.each do |obj|
                    obj_ref = references[obj.object_id]

                    test_and_add_reference(obj_ref, obj.class, "class")

                    for var_name in obj.instance_variables
                        var = obj.instance_variable_get(var_name)
                        test_and_add_reference(obj_ref, var, var_name.to_s)
                    end

                    case obj
                    when Array, ValueSet
                        for var in obj
                            test_and_add_reference(obj_ref, var, "ValueSet[]")
                        end
                    when BGL::Graph
                        obj.each_vertex do
                            test_and_add_reference(obj_ref, var, "Vertex[]")
                        end
                        obj.each_edge do |_, _, info|
                            test_and_add_reference(obj_ref, info, "Edge[]")
                        end
                    when Hash
                        for var in obj
                            2.times do |i|
                                test_and_add_reference(obj_ref, var[i], "Hash[]")
                            end
                        end
                    when Proc
                        if obj.respond_to?(:references)
                            for var in obj.references
                                begin
                                    test_and_add_reference(obj_ref, ObjectSpace._id2ref(var), "Proc")
                                rescue RangeError
                                end
                            end
                        end
                    else
                        if obj.respond_to?(:each)
                            if obj.kind_of?(Module) || obj.kind_of?(Class)
                                if !ignored_enumeration[obj]
                                    ignored_enumeration[obj] = true
                                    puts "ignoring enumerator class/module #{obj}"
                                end
                            else
                                if !ignored_enumeration[obj.class]
                                    ignored_enumeration[obj.class] = true
                                    puts "ignoring enumerator object #{obj.class}"
                                end
                            end
                        end
                    end
                end
                if old_graph_size == graph.size
                    break
                end
            end
            return graph
        end

        def collapse(*klasses)
            vertices = graph.vertices.dup
            vertices.each do |v|
                case v.obj
                when *klasses
                    next if v.root?(graph) || v.leaf?(graph)

                    v.each_parent_vertex(graph) do |parent|
                        all_parent_info = parent[v, graph]
                        v.each_child_vertex(graph) do |child|
                            all_child_info = v[child, graph]
                            all_parent_info.each do |parent_info|
                                all_child_info.each do |child_info|
                                    add_reference(parent, child, parent_info + "." + child_info)
                                end
                            end
                        end
                    end
                    graph.remove(v)
                end
            end
        end

        def to_dot
            if !roots
                roots = graph.vertices.find_all do |v|
                    v.root?(graph)
                end.to_value_set
            else
                roots = roots.to_value_set
            end

            io = StringIO.new("")

            all_seen = ValueSet.new
            io.puts "digraph {"
            roots.each do |obj_ref|
                seen = ValueSet.new
                graph.each_dfs(obj_ref, BGL::Graph::ALL) do |from_ref, to_ref, all_info, kind|
                    info = all_info.to_a.join(",")

                    if all_seen.include?(from_ref)
                        graph.prune
                    else
                        from_id = from_ref.obj.object_id
                        to_id   = to_ref.obj.object_id
                        io.puts "obj#{from_id} -> obj#{to_id} [label=\"#{info}\"]"
                    end
                    seen << from_ref << to_ref
                end

                seen.each do |obj_ref|
                    if !all_seen.include?(obj_ref)
                        obj = obj_ref.obj
                        obj_id = obj_ref.obj.object_id
                        str =
                            if obj.respond_to?(:each)
                                "#{obj.class}"
                            else
                                obj.to_s
                            end

                        color =
                            if obj.kind_of?(Roby::EventGenerator)
                                "cyan"
                            elsif obj.kind_of?(Roby::Task)
                                "blue"
                            elsif obj.kind_of?(BGL::Graph)
                                "magenta"
                            elsif obj.kind_of?(Hash) || obj.kind_of?(Array) || obj.kind_of?(ValueSet)
                                "green"
                            else
                                "black"
                            end

                        io.puts "obj#{obj_id} [label=\"#{str}\",color=#{color}];"
                    end
                end
                all_seen.merge(seen)
            end
            io.puts "}"
            io.string
        end
    end
    end
end

