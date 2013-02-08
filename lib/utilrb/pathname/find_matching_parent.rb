require 'pathname'
class Pathname
    # Returns the path object that is the first parent of self matching the
    # given predicate
    #
    # @yieldparam [Pathname] path the path object that should be tested
    # @yieldreturn [Boolean] true if this is the path you are looking for, and
    #   false otherwise
    # @return [Pathname,nil] the matching path or nil if none could be found
    def find_matching_parent
        # Look for a bundle in the parents of Dir.pwd
        curdir = self
        while !curdir.root? && !yield(curdir)
            curdir = curdir.parent
        end
        if !curdir.root?
            curdir
        end
    end
end
