require "msgpack_rpc_client/version"
require 'msgpack'
require 'socket'

# MessagePack-RPC client
class MsgpackRpcClient
  class Error < RuntimeError; end

  DEFAULT_MAX_RETRIES = 10
  DEFAULT_MAX_CONNECT_RETRIES = 5
  DEFAULT_CONNECT_RETRY_WAIT = 0.1 # seconds
  MAX_MSGID = 1_000_000_000

  attr_reader :host, :port, :use_ssl, :max_retries, :max_connect_retries, :connect_retry_wait

  # Initialize client and establish connection to server.
  #
  # (While it may seem beneficial to not connect in the constructor and wait for
  # the first RPC call, I believe it's better to fail early.
  #
  # * host, port, use_ssl - configure your connection
  # * logger - logger (default nil, set to Rails.logger in a Rails app)
  #
  # Parameters that are better left alone:
  # * max_retries - number of times to retry sending a request
  # * max_connect_retries - number of times to retry connecting to the server
  # * connect_retry_wait - wait between connection retry attempts
  #
  # TODO: once we are long past the <2.0.0 legacy, replace with named args
  def initialize(options={})
    @host = options.fetch(:host)
    @port = options.fetch(:port)
    @use_ssl = options.fetch(:use_ssl, false)
    @logger = options.fetch(:logger, nil)
    @max_retries = options.fetch(:max_retries, DEFAULT_MAX_RETRIES)
    @max_connect_retries = options.fetch(:max_connect_retries, DEFAULT_MAX_CONNECT_RETRIES)
    @connect_retry_wait = options.fetch(:connect_retry_wait, DEFAULT_CONNECT_RETRY_WAIT)
    @msgid = 1
    @call_mutex = Mutex.new
    init_socket
  end

  # Call an RPC method. Will reconnect if the server is down. Threadsafe.
  #
  # * Params is anything serializable with Messagepack.
  # * Hashes in response will be deserialized with symbolized keys
  def call(method_name, *params)
    request = nil
    response = nil

    @call_mutex.synchronize do
      request = [0, @msgid, method_name, params]
      @msgid = (@msgid % MAX_MSGID) + 1
      response = make_request_with_retries(request)
    end

    if response[0] != 1
      raise MsgpackRpcClient::Error, 'Response does not bear the proper type flag - something is very wrong'
    end
    if response[1] != request[1]
      raise MsgpackRpcClient::Error, 'Response message id does not match request message id - something is very wrong'
    end
    if response[2] != nil
      raise MsgpackRpcClient::Error, "Server responded with error: #{response[2]}"
    end

    response[3]
  end

  private

  # Handles socket connectivity details of sending and receiving. Retries on error.
  def make_request_with_retries(request)
    retry_count = 0
    begin
      @packer.write(request).flush
      @unpacker.read
    rescue EOFError, IOError, Errno::EPIPE, Errno::ETIMEDOUT, Errno::ECONNRESET
      @logger.error("[MSGPACK-RPC] Msgpack-RPC socket interrupted. Re-establishing commmunications.") if @logger
      retry_count += 1
      if retry_count == max_retries
        raise MsgpackRpcClient::Error, "Failed to re-establish communications with server"
      else
        init_socket
        retry
      end
    end
  end

  # Opens a socket according to provided configuration. Retries on error.
  def init_socket
    @socket.close if @socket
    retry_count = 0
    begin
      @logger.info("[MSGPACK-RPC] Connecting to Msgpack-RPC server...") if @logger
      @socket = TCPSocket.new(host, port)
      configure_socket_keepalive
      init_ssl if use_ssl
    rescue Errno::ECONNREFUSED
      @logger.error("[MSGPACK-RPC] Connection refused") if @logger
      retry_count += 1
      if retry_count == max_connect_retries
        raise MsgpackRpcClient::Error, "Could not connect to MsgPack-RPC server"
      else
        sleep(connect_retry_wait)
        # might have a chance with a different instance
        retry
      end
    end
    # Attach streaming packer/unpacker to the socket
    @packer = MessagePack::Packer.new(@socket)
    @unpacker = MessagePack::Unpacker.new(@socket, symbolize_keys: true)
  end

  # Configure the TCP stack to send keepalive messages, as we want a long-living
  # connection.
  #
  # (Not 100% reliable)
  def configure_socket_keepalive
    @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
    if defined?(Socket::TCP_KEEPINTVL) # Not available on JRuby
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPINTVL, 10)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT, 5)
    end
    if defined?(Socket::TCP_KEEPIDLE) # Not available on BSD / OSX
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPIDLE, 50)
    end
  end

  # Open an SSL socket on top of the TCP socket.
  #
  # VERIFY_PEER is mandatory; if you have problems with it, just don't use SSL -
  # without verification it gives no security benefits but only increases cpu load.
  def init_ssl
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
    # We are overwriting the TCP socket with the SSL socket here.
    @socket = OpenSSL::SSL::SSLSocket.new(@socket, ctx)
    @socket.sync_close = true
    @socket.connect
  end
end
