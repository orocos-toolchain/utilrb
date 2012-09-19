module Utilrb
    module Timepoints
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
    end
end

