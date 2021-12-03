# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'utilrb/version'

Gem::Specification.new do |s|
    s.name = "utilrb"
    s.version = Utilrb::VERSION
    s.authors = ["Sylvain Joyeux"]
    s.email = "sylvain.joyeux@m4x.org"
    s.summary = "Utilrb is yet another Ruby toolkit, in the spirit of facets"
    s.description = "Utilrb is yet another Ruby toolkit, in the spirit of facets. It includes all\nthe standard class extensions I use in other projects."
    s.homepage = "http://rock-robotics.org"
    s.licenses = ["BSD"]

    s.require_paths = ["lib"]
    s.extra_rdoc_files = ["License.txt"]
    s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

    s.add_runtime_dependency "facets", ">= 2.4.0"
    s.add_runtime_dependency "rake", ">= 0.9"
    s.add_runtime_dependency "backports", "~> 3.11"
    s.add_development_dependency "flexmock", ">= 2.0.0"
    s.add_development_dependency "minitest", ">= 5.0", "~> 5.0"
    s.add_development_dependency "coveralls"
end
