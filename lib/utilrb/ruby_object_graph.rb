require 'stringio'
require 'utilrb/value_set'
require 'utilrb/kernel/options'
module Utilrb
    begin
        require 'roby/graph'
        has_roby_graph = true
    rescue LoadError
        has_roby_graph = false
    end

    if has_roby_graph
    class RubyObjectGraph
        module GraphGenerationObjectMaker
            def __ruby_object_graph_internal__; end
        end
        attr_reader :graph
        attr_reader :references

        # Takes a snapshot of all objects currently live
        def self.snapshot
            # Doing any Ruby code that do not modify the heap is impossible. List
            # all existing objects once, and only then do the processing.
            # +live_objects+ will be referenced in itself, but we are going to
            # remove it later
            GC.disable
            live_objects = Array.new
            ObjectSpace.each_object do |obj|
                if obj.object_id != live_objects.object_id
                    live_objects << obj
                end
            end
            GC.enable
            live_objects
        end

        # Generates a graph of all the objects currently live, in dot format
        def self.dot_snapshot(options = Hash.new)
            r, w = IO.pipe
            puts "before fork"
            live_objects = RubyObjectGraph.snapshot
            fork do
                puts "in fork"
                options, register_options = Kernel.filter_options options,
                    :collapse => nil
                ruby_graph = RubyObjectGraph.new
                ruby_graph.register_references_to(live_objects, register_options)
                if options[:collapse]
                    ruby_graph.collapse(*options[:collapse])
                end
                w.write ruby_graph.to_dot
                exit! true
            end
            w.close
            r.read
        end

        def initialize
            @graph = BGL::Graph.new
            @references = Hash.new
        end

        def clear
            graph.each_edge do |from, to, info|
                info.clear
            end
            graph.clear
            references.clear
        end

        # This class is used to store any ruby object into a BGL::Graph (i.e.
        # the live graph)
        class ObjectRef
            # The referenced object
            attr_reader :obj

            def __ruby_object_graph_internal__; end

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

        # Register a ruby object reference
        #
        # @param [ObjectRef] obj_ref the object that is referencing
        # @param [ObjectRef] var_ref the object that is referenced
        # @param desc the description for the link. For instance, if obj_ref
        #   references var_ref because of an instance variable, this is going to
        #   be the name of the instance variable
        # @return [void]
        def add_reference(obj_ref, var_ref, desc)
            if graph.linked?(obj_ref, var_ref)
                desc_set = obj_ref[var_ref, graph]
                if !desc_set.include?(desc)
                    desc_set << desc
                end
            else
                desc_set = [desc]
                graph.link(obj_ref, var_ref, desc_set)
            end
        end

        # Creates a BGL::Graph of ObjectRef objects which stores the current
        # ruby object graph
        #
        # @param [Class] klass seed 
        # @option options [Array<Object>] roots (nil) if given, the list of root
        #   objects. Objects that are not referenced by one of these roots will
        #   not be included in the final graph
        def register_references_to(live_objects, options = Hash.new)
            orig_options = options # to exclude it from the graph
            options = Kernel.validate_options options,
                :roots => [Object], :excluded_classes => [], :excluded_objects => [],
                :include_class_relation => false
            roots_class, roots = options[:roots].partition { |obj| obj.kind_of?(Class) }
            excluded_classes = options[:excluded_classes]
            excluded_objects = options[:excluded_objects]
            include_class_relation = options[:include_class_relation]

            # Create a single ObjectRef per (interesting) live object, so that we
            # can use a BGL::Graph to represent the reference graph.  This will be
            # what we are going to access later on. Use object IDs since we really
            # want to refer to objects and not use eql? comparisons
            desired_seeds = roots.map(&:object_id)
            excludes = [live_objects, self, graph, references, orig_options, options, roots, roots_class].to_value_set
            live_objects_total = live_objects.size
            live_objects.delete_if do |obj|
                if excludes.include?(obj) || obj.respond_to?(:__ruby_object_graph_internal__)
                    true
                else
                    references[obj.object_id] ||= ObjectRef.new(obj)
                    if roots_class.any? { |k| obj.kind_of?(k) }
                        if !excluded_classes.any? { |k| obj.kind_of?(k) }
                            if !excluded_objects.include?(obj)
                                desired_seeds << obj.object_id
                            end
                        end
                    end
                    false
                end
            end

            desired_seeds.each do |obj_id|
                graph.insert(references[obj_id])
            end
            ignored_enumeration = Hash.new

            names = Hash[
                :array => "Array",
                :value_set => "ValueSet[]",
                :vertex => "Vertex[]",
                :edge => "Edge[]",
                :hash_key => "Hash[key]",
                :hash_value => "Hash[value]",
                :proc => "Proc"]
            puts "RubyObjectGraph: #{live_objects.size} objects found, #{desired_seeds.size} seeds and #{live_objects_total} total live objects"
            loop do
                old_graph_size = graph.size
                live_objects.each do |obj|
                    obj_ref = references[obj.object_id]

                    if include_class_relation
                        test_and_add_reference(obj_ref, obj.class, "class")
                    end

                    for var_name in obj.instance_variables
                        var = obj.instance_variable_get(var_name)
                        test_and_add_reference(obj_ref, var, var_name.to_s)
                    end

                    case obj
                    when Array
                        for var in obj
                            test_and_add_reference(obj_ref, var, names[:array])
                        end
                    when ValueSet
                        for var in obj
                            test_and_add_reference(obj_ref, var, names[:value_set])
                        end
                    when BGL::Graph
                        obj.each_vertex do
                            test_and_add_reference(obj_ref, var, names[:vertex])
                        end
                        obj.each_edge do |_, _, info|
                            test_and_add_reference(obj_ref, info, names[:edge])
                        end
                    when Hash
                        for var in obj
                            test_and_add_reference(obj_ref, var[0], names[:hash_key])
                            test_and_add_reference(obj_ref, var[1], names[:hash_value])
                        end
                    when Proc
                        if obj.respond_to?(:references)
                            for var in obj.references
                                begin
                                    test_and_add_reference(obj_ref, ObjectSpace._id2ref(var), names[:proc])
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
                                    puts "ignoring enumerator object of class #{obj.class}"
                                end
                            end
                        end
                    end
                end
                if old_graph_size == graph.size
                    break
                end
            end
            live_objects.clear # to avoid making it a central node in future calls
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
            roots = graph.vertices.find_all do |v|
                v.root?(graph)
            end.to_value_set

            io = StringIO.new("")

            colors = Hash[
                :green => 'green',
                :magenta => 'magenta',
                :black => 'black'
            ]
            obj_label_format = "obj%i [label=\"%s\",color=%s];" 
            obj_label_format_elements = []
            edge_label_format_0 = "obj%i -> obj%i [label=\""
            edge_label_format_1 = "\"];"
            edge_label_format_elements = []

            all_seen = ValueSet.new
            seen = ValueSet.new
            io.puts "digraph {"
            roots.each do |obj_ref|
                graph.each_dfs(obj_ref, BGL::Graph::ALL) do |from_ref, to_ref, all_info, kind|
                    info = []
                    for str in all_info
                        info << str
                    end

                    if all_seen.include?(from_ref)
                        graph.prune
                    else
                        from_id = from_ref.obj.object_id
                        to_id   = to_ref.obj.object_id

                        edge_label_format_elements.clear
                        edge_label_format_elements << from_id << to_id
                        str = edge_label_format_0 % edge_label_format_elements
                        first = true
                        for edge_info in all_info
                            if !first
                                str << ","
                            end
                            str << edge_info
                            first = false
                        end
                        str << edge_label_format_1

                        io.puts str
                    end
                    seen << from_ref << to_ref
                end

                for obj_ref in seen
                    if !all_seen.include?(obj_ref)
                        obj = obj_ref.obj
                        obj_id = obj_ref.obj.object_id
                        str =
                            if obj.respond_to?(:each)
                                "#<#{obj.class}: #{obj.object_id}>"
                            else
                                obj.to_s
                            end

                        color =
                            if obj.kind_of?(BGL::Graph)
                                :magenta
                            elsif obj.kind_of?(Hash) || obj.kind_of?(Array) || obj.kind_of?(ValueSet)
                                :green
                            else
                                :black
                            end

                        obj_label_format_elements.clear
                        obj_label_format_elements << obj_id << str.gsub(/[\\"\n]/, " ") << colors[color]
                        str = obj_label_format % obj_label_format_elements
                        io.puts(str)
                    end
                end
                all_seen.merge(seen)
                seen.clear
            end
            roots.clear
            all_seen.clear
            seen.clear
            io.puts "}"
            io.string
        end
    end
    end
end

