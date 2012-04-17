require 'pp'
module Utilrb
    module YARD
        include ::YARD
        class InheritedEnumerableHandler < YARD::Handlers::Ruby::AttributeHandler
            handles method_call(:inherited_enumerable)
            namespace_only

            def process
                name = statement.parameters[0].jump(:tstring_content, :ident).source
                if statement.parameters.size == 3
                    attr_name = statement.parameters[1].jump(:tstring_content, :ident).source
                else
                    attr_name = name
                end
                options = statement.parameters[-1]

                is_map = false
                if options
                    options.each do |opt|
                        key = opt.jump(:assoc)[0].jump(:ident).source
                        value = opt.jump(:assoc)[1].jump(:ident).source
                        if key == "map" && value == "true"
                            is_map = true
                        end
                    end
                end

                push_state(:scope => :class) do
                    object = YARD::CodeObjects::MethodObject.new(namespace, attr_name, scope) do |o|
                        o.dynamic = true
                        o.aliases << "self_#{name}"
                    end
                    register(object)
                    key_name =
                        if object.docstring.has_tag?('key_name')
                            object.docstring.tag('key_name').text
                        else
                            'key'
                        end
                    return_type =
                        if object.docstring.has_tag?('return')
                            object.docstring.tag('return').types.first
                        elsif is_map
                            'Hash<Object,Object>'
                        else
                            'Array<Object>'
                        end
                    if return_type =~ /^\w+\<(.*)\>$/
                        if is_map
                            key_type, value_type = $1.split(',')
                        else
                            value_type = $1
                        end
                    else
                        key_type = "Object"
                        value_type = "Object"
                    end

                    object = YARD::CodeObjects::MethodObject.new(namespace, "all_#{name}", scope)
                    object.dynamic = true 
                    register(object)
                    object.docstring.replace("The union, along the class hierarchy, of all the values stored in #{name}\n@return [Array<#{value_type}>]")

                    if is_map
                        object = YARD::CodeObjects::MethodObject.new(namespace, "find_#{name}", scope)
                        object.dynamic = true 
                        register(object)
                        object.parameters << [key_name]
                        object.docstring.replace("Looks for objects registered in #{name} under the given key, and returns the first one in the ancestor chain (i.e. the one tha thas been registered in the most specialized class)\n@return [#{value_type},nil] the found object, or nil if none is registered under that key")

                        object = YARD::CodeObjects::MethodObject.new(namespace, "has_#{name}?", scope)
                        object.dynamic = true 
                        register(object)
                        object.parameters << [key_name]
                        object.docstring.replace("Returns true if an object is registered in #{name} anywhere in the class hierarchy\n@return [Boolean]")
                        object.signature = "def has_#{name}?(key)"

                        object = YARD::CodeObjects::MethodObject.new(namespace, "each_#{name}", scope)
                        object.dynamic = true 
                        register(object)
                        object.parameters << [key_name, "nil"] << ["uniq", "true"]
                        object.docstring.replace("
@overload each_#{name}(#{key_name}, uniq = true)
    Enumerates all objects registered in #{name} under the given key
    @yield [element]
    @yieldparam [#{value_type}] element
@overload each_#{name}(nil, uniq = true)
    Enumerates all objects registered in #{name}
    @yield [#{key_name}, element]
    @yieldparam [#{key_type}] #{key_name}
    @yieldparam [#{value_type}] element
                        ")
                    else
                        object = YARD::CodeObjects::MethodObject.new(namespace, "each_#{name}", scope)
                        object.dynamic = true 
                        register(object)
                        object.docstring.replace("Enumerates all objects registered in #{name}\n@return []\n@yield [element]\n@yieldparam [#{value_type}] element")
                    end
                end
            end
        end
        YARD::Tags::Library.define_tag("Key for inherited_enumerable(_, :map => true)", :key_name)

        class AttrEnumerableHandler < YARD::Handlers::Ruby::AttributeHandler
            handles method_call(:attr_enumerable)
            namespace_only

            def process
                name = statement.parameters.first.jump(:tstring_content, :ident).source

                object = YARD::CodeObjects::MethodObject.new(namespace, name, scope)
                object.dynamic = true 
                register(object)
                object = YARD::CodeObjects::MethodObject.new(namespace, "#{name}=", scope)
                object.dynamic = true 
                register(object)
                object = YARD::CodeObjects::MethodObject.new(namespace, "each_#{name}", scope)
                object.dynamic = true 
                register(object)
            end
        end

        class AttrPredicateHandler < YARD::Handlers::Ruby::AttributeHandler
            handles method_call(:attr_predicate)
            namespace_only

            def process
                name = statement.parameters.first.jump(:tstring_content, :ident).source

                rw = false
                if statement.parameters[1]
                    rw = (statement.parameters[1].jump(:kw).source == "true")
                end

                if name.to_s =~ /^(.*)\?$/
                    name = $1
                end
                wname, pname = "#{name}=", "#{name}?"

                object = YARD::CodeObjects::MethodObject.new(namespace, pname, scope)
                object.dynamic = true 
                register(object)
                object.docstring.create_tag("return", "[Boolean]")
                if rw
                    object = YARD::CodeObjects::MethodObject.new(namespace, wname, scope)
                    object.dynamic = true 
                    object.parameters << ["value", nil]
                    object.signature
                    object.docstring.create_tag("param", "[Boolean] value")
                    object.docstring.create_tag("return", "[Boolean]")
                end
            end
        end
    end
end
