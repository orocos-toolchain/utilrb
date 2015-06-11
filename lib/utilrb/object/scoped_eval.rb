require 'utilrb/common'
require 'utilrb/kernel/with_module'
class Object
    def scoped_eval(type = :instance_eval, &b)
        send(type, &b)
    end
end

