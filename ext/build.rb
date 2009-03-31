ENV['CC'] = `which g++`.chomp
extension do |e|
    e.name 'utilrb_ext'
    e.files 'utilrb_ext.cc'
    e.files 'value_set.cc'
    e.includes '.'
    e.compile_flags "-DRUBINIUS"
end

