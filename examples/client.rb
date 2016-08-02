# Run server.go in a parallel process first

require 'msgpack_rpc_client'

client = MsgpackRpcClient.new(host: '127.0.0.1', port: 12345)

response = client.call('Greeter.HelloWorld', name: 'Ruby')
# {:greeting=>"Hello, Ruby"}
puts response[:greeting]

puts client.call('Greeter.HelloWorld', {})
# {:error=>"Name is required"}

puts client.call('Greeter.BogusMethod', {})
# MsgpackRpcError exception: Server responded with error: rpc: can't find method Greeter.BogusMethod
