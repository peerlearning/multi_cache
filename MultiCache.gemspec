# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'MultiCache/version'

Gem::Specification.new do |spec|
  spec.name          = "MultiCache"
  spec.version       = MultiCache::VERSION
  spec.authors       = ["Shivam"]
  spec.email         = ["shvamverma@gmail.com"]

  spec.summary       = %q{MultiCache provides a framework to help you cache at model level}
  spec.description   = %q{MultiCache provides a framework to help you cache at model level on redis under a specific namespace}
  spec.homepage      = "http://www.avanti.in"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "redis", "~>3.2.2"
  spec.add_development_dependency "redis-namespace", "~>1.5.2"
end
