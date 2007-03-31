class UnboundMethod
    # Calls this method on +obj+ with the +args+ and +block+ arguments. This
    # allows to have an uniform way to call methods on objects
    def call(obj, *args, &block)
	bind(obj).call(*args, &block)
    end
end
