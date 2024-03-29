require 'tm_sync/exceptions'
require 'tm_sync/utils'

module TmSync

  class ConnectionState < Enum

    def initialize(sendable)
      self.sendable = sendable
    end

    attr_accessor :sendable
    private :sendable=
    alias_method :sendable?, :sendable
    undef_method :sendable

    value :INITIALIZED, true
    value :OPEN,        true
    value :BROKEN,      false
    value :CLOSED,      false

  end

  module HalfDuplexConnection

    DATAGRAM_CONNECTION_TOKEN = '00000000-0000-0000-0000-000000000000'

    def token
      DATAGRAM_CONNECTION_TOKEN
    end

    def increment_sequence_number
      0
    end

    def is_receiving?
      true
    end

    def is_sending?
      true
    end

    def lock_connection
      yield
    end

    class Simple
      include HalfDuplexConnection
    end

  end

  module Connection
    attr_accessor :connection_manager

    def state

    end

    def state=(value)

    end

    def datagram?
      false
    end

    def endpoint
      nil
    end

    def outbound_connection
      HalfDuplexConnection::Simple.new
    end

    def inbound_connection
      HalfDuplexConnection::Simple.new
    end

    def receive(request)
      raise ConnectionBrokenException.new if not state.sendable?
      inbound_connection.lock_connection do
        break! if request.sequence_number != inbound_connection.increment_sequence_number
        return request.command
      end
    end

    def send_message(request)
      raise ConnectionBrokenException.new if not state.sendable?
      request.connection = self
      request.token = outbound_connection.token

      err = nil
      response = nil

      outbound_connection.lock_connection do
        request.sequence_number = outbound_connection.increment_sequence_number
        begin
          response = request.send!
        rescue => e
          err = e
          break_silently
        end
      end

      raise err if err
      if response.response_code == "504"
        break!
      end
      return response
    end

    def close!
      self.state = ConnectionState::CLOSED
    end

    def close
      request = TmSync::Request.new
      request.command = TmSync::Command::Unregister.new
      begin
        send_message(request)
      ensure
        close!
      end
    end

    private
    def break!
      break_silently
      raise ConnectionBrokenException.new
    end

    def break_silently
      self.state=ConnectionState::BROKEN
    end
  end

  class DatagramConnection
    include Connection

    attr_accessor :url
    alias_method :endpoint, :url

    def datagram?
      true
    end

    def initialize(url)
      self.url = url
    end

    def state
      ConnectionState::OPEN
    end
  end

  module ConnectionManager

    attr_accessor :debug

    private
    def datagram_connection
      @datagram_connection ||= DatagramConnection.new(nil)
      @datagram_connection.connection_manager = self
      @datagram_connection
    end

    public
    def find_connection_by_token(token)
      return datagram_connection if token == HalfDuplexConnection::DATAGRAM_CONNECTION_TOKEN
    end

    ##
    # Ignoring flags for now
    def create_connection(uri, token, flags)

    end

    def receive_url

    end

    def receive(request, &block)
      response = _receive(request, &block)
      response.send!
      response
    end

    def _receive(request)
      response = TmSync::Response.new
      response.request = request
      response.payload = {}

      connection = find_connection_by_token request.token
      request.connection = connection

      if connection.nil?
        response.response_code = 401
        response.error = 'Unrecognized token'
        return response
      end

      begin
        connection.receive(request)

        response.response_code = 200
        yield request, response

      # Handle a broken exception
      rescue ConnectionBrokenException
        response.response_code = 504
        response.error = 'Connection broken'
      end

      return response

    # Make sure the server responds to ISEs appropriately
    rescue Exception => e
      previous_response = response
      response = TmSync::Response.new
      response.request = request
      response.payload = {}
      response.response_code = 500

      if debug
        response.error = e.to_s
        response.payload = previous_response.to_h
      else
        response.error = 'Internal Server Error'
      end

      raise e
    end

    def send_command(command, connection)
      request = TmSync::Request.new
      request.command = command

      connection.send_message(request)
    end

    def create_token

    end

    def defer(&block)

    end

  end
end