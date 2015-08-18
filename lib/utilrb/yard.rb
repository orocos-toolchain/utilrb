require 'pp'
module Utilrb
    module YARD
        include ::YARD
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
                object.docstring.add_tag(YARD::Tags::Tag.new(:return, nil, ['Boolean']))
                if rw
                    object = YARD::CodeObjects::MethodObject.new(namespace, wname, scope)
                    object.dynamic = true 
                    object.parameters << ["value", nil]
                    object.signature
                    object.docstring.add_tag(YARD::Tags::Tag.new(:param, 'value', ['Boolean'], nil))
                    object.docstring.add_tag(YARD::Tags::Tag.new(:return, nil, ['Boolean'], nil))
                    register(object)
                end
            end
        end
    end
end
