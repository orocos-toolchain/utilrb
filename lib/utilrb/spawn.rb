require 'fcntl'

module Utilrb
    class SpawnFailed < RuntimeError; end
    def self.spawn(*cmdline)
        options =
            if cmdline.last.kind_of?(Hash)
                cmdline.pop
            else Hash.new
            end

        options = Kernel.validate_options options, :redirect => nil,
            :working_directory => nil,
            :nice => nil

        output  = options[:redirect]
        workdir = options[:working_directory]

        read, write = IO.pipe
        pid = fork do 
            if output
                if !output.kind_of?(IO)
                    output_file_name = output.
                        gsub('%p', ::Process.pid.to_s)
                    if workdir
                        output_file_name = File.expand_path(output_file_name, workdir)
                    end
                    output = File.open(output, 'a')
                end
            end
            
            if output
                STDERR.reopen(output)
                STDOUT.reopen(output)
            end

            read.close
            write.sync = true
            write.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
            ::Process.setpgrp
            if options[:nice]
                Process.setpriority(Process::PRIO_PROCESS, 0, options[:nice])
            end

            begin
                if workdir
                    Dir.chdir(workdir)
                end
                exec(*cmdline)
            rescue Exception
                write.write("FAILED")
            end
        end

        write.close
        if read.read == "FAILED"
            raise SpawnFailed, "cannot start #{cmdline.inspect}"
        end
        pid
    end
end

