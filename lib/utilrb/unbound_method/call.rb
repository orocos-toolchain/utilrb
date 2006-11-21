class UnboundMethod
    def call(obj, *args, &block)
	bind(obj).call(*args, &block)
    end
end
