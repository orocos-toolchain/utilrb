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
            start_points = Hash.new
            result = []
            @timepoints.inject(@timepoints.first.first) do |last_t, (t, name)|
                if name.last == 'start'
                    start_points[name[0..-2]] = t
                elsif name.last == 'done'
                    total = t - start_points.delete(name[0..-2])
                    name = name + ["total=%.3f" % total]
                end
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

