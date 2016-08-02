require 'spec_helper'

describe MsgpackRpcClient do
  let!(:echo_server_thread) do
    Thread.new do
      server = TCPServer.new(12345)
      loop do
        client = server.accept
        request = MessagePack::Unpacker.new(client, symbolize_keys: true).read
        response = [1, request[1], nil, request[3].first]
        MessagePack::Packer.new(client).write(response).flush
        client.close
      end
    end
  end

  subject { described_class.new(host: 'localhost', port: 12345) }

  it 'should connect to a server' do
    expect(subject.call('test', 'foo')).to eq('foo')
  end

  it 'should support more than one request' do
    expect(subject.call('test', 'foo')).to eq('foo')
    expect(subject.call('test', 'bar')).to eq('bar')
  end

  it 'should be threadsafe' do
    expect do
      threads = Array.new(10) do |i|
        Thread.new do
          100.times do |j|
            message = "foo_#{i}_#{j}"
            expect(subject.call('echo', message)).to eq(message)
          end
        end
      end
      threads.each(&:join)
    end.to_not raise_error
  end
end
