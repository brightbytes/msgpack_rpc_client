# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'msgpack_rpc_client/version'

Gem::Specification.new do |spec|
  spec.name          = "msgpack_rpc_client"
  spec.version       = MsgpackRpcClient::VERSION
  spec.authors       = ["Leonid Shevtsov"]
  spec.email         = ["leonid@shevtsov.me"]

  spec.summary       = %q{A lean client for Messagepack-RPC.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "msgpack"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
