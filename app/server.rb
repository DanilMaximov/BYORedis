# frozen_string_literal: true

require 'socket'
require_relative './helpers/resp'
class YourRedisServer
  def initialize(port)
    @server = TCPServer.new(port)
    @clients = []

    puts "Listening on port #{port}"
  end

  def start
    Thread.new do
      loop do
        new_client = @server.accept
        @clients << new_client
      end
    end

    loop do
      sleep(0.1) if @clients.empty?

      @clients.each do |client|
        client_message = client.read_nonblock(256, exception: false)

        @clients.delete(client) if client.closed?
        next if client_message == :wait_readable || client_message.nil?

        response = handle_client_command(client_message)
        client.puts response
      end
    end
  end

  private

  def handle_client_command(message)
    request_message = RESP.parse(message)
    command = request_message.shift.downcase

    case command
    when /echo/
      RESP.generate(request_message[0])
    when /get/
      RESP.generate(@storage[request_message[0]] || nil)
    when /set/
      @storage[request_message[0]] = request_message[1]

      RESP.generate('OK')
    else
      RESP.generate('PONG')
    end
  end
end

YourRedisServer.new(6379).start
