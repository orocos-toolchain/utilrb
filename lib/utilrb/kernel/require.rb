module Kernel
    # Require all .rb files in the +filename+ directory
    def require_dir(filename)
	dirname = filename.gsub(/.rb$/, '')
	Dir.new(dirname).each do |file|
	    if file =~ /\.rb$/
		require File.join(dirname, file)
	    end
	end
    end
end

