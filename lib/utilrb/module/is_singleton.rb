require 'utilrb/module/singleton_class_p'
puts "WARN Module#is_singleton? has been renamed to #singleton_class? to match the built-in method in Ruby 2.1+"
puts "WARN require 'utilrb/module/singleton_class_p instead of is_singleton?"
class Module
    alias :is_singleton? :singleton_class?
end
