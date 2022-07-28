
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "prometheus_aggregator/version"

Gem::Specification.new do |spec|
  spec.name          = "prometheus_aggregator"
  spec.version       = PrometheusAggregator::VERSION
  spec.authors       = ["Harry Marr"]
  spec.email         = ["support@dependabot.com"]

  spec.summary       = "Client for https://github.com/peterbourgon/prometheus-aggregator"
  spec.homepage      = "https://github.com/dependabot/prometheus-aggregator-ruby"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "net_tcp_client", "~> 2.0"

  spec.add_development_dependency "excon", "~> 0.62"
  spec.add_development_dependency "faraday", "~> 2.4"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rack", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.3"
end
