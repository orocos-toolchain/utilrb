
class Exception
    def full_message
	first, *remaining = backtrace
	"#{first}: #{message} (#{self.class})\n\tfrom " + remaining.join("\n\tfrom ")
    end
end

