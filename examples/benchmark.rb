# Run server.go in a parallel process first

require 'json'
require 'msgpack_rpc_client'
require 'benchmark/ips'

msgpack_client = MsgpackRpcClient.new('127.0.0.1', 12345)
http_uri = URI('http://localhost:12344/hello_world')

Benchmark.ips do |x|
  x.report 'http/json' do
    req = Net::HTTP::Post.new(http_uri, 'Content-Type' => 'application/json')
    req.body = { name: 'Ruby' }.to_json
    res = Net::HTTP.start(http_uri.hostname, http_uri.port) do |http|
      http.request(req)
    end
    JSON.parse(res.body, symbolize_keys: true)
  end

  x.report 'msgpack-rpc' do
    msgpack_client.call('Greeter.HelloWorld', name: 'Ruby')
  end

  x.compare!
end
