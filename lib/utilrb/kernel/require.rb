module Kernel
    # Require all .rb files in the +filename+ directory
    def require_dir(filename, exclude = nil)
	dirname = filename.gsub(/.rb$/, '')
	Dir.new(dirname).each do |file|
            next if exclude && exclude === file
	    if file =~ /\.rb$/
		require File.join(dirname, file)
	    end
	end
    end
end

