require 'set'
class Set
    def to_s
	"{ #{map { |o| o.to_s }.join(", ")} }"
    end
end

