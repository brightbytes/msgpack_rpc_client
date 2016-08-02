# This implementation isn't production-tested, so it's not included in the gem
# istelf. But you're welcome to polish it up and submit a PR.
#
# After starting `ruby server.rb`, run `ruby client.rb` in a separate shell.

require 'socket'
require 'msgpack'

def hello_world(args)
  if args[:name]
    {greeting: "Hello, #{args[:name]}"}
  else
    {error: "Name is required"}
  end
end

def call_rpc_method(api_method, params)
  case api_method
  when 'Greeter.HelloWorld'
    [hello_world(*params), nil]
  else
    return [nil, "Unknown method #{api_method}"]
  end
end

server = TCPServer.new(12345)
puts 'Server listening on port 12345, Ctrl+C to stop'
loop do
  Thread.start(server.accept) do |client|
    unpacker = MessagePack::Unpacker.new(client, symbolize_keys: true)
    packer = MessagePack::Packer.new(client)
    loop do
      rpc_request = unpacker.read
      response, error = call_rpc_method(rpc_request[2], rpc_request[3])
      rpc_response = [1, rpc_request[1], error, response]
      packer.write(rpc_response).flush
    end
  end
end
