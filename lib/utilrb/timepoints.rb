module Utilrb
    module Timepoints
        def timepoints
            @timepoints || Array.new
        end

        def clear_timepoints
            @timepoints ||= Array.new
            @timepoints.clear
        end

        def add_timepoint(*names)
            @timepoints ||= Array.new
            @timepoints << [Time.now, names]
        end

        def format_timepoints
            result = []
            @timepoints.inject(@timepoints.first.first) do |last_t, (t, name)|
                result << name + [t - last_t]
                t
            end
            result
        end

        def merge_timepoints(other)
            data =
                if other.respond_to?(:to_ary)
                    other.to_ary
                else
                    other.timepoints
                end
            @timepoints = (timepoints + data).sort_by(&:first)
            self
        end
    end
end

