require 'tm_sync/core/connection'
require 'tm_sync/core/request'
require 'tm_sync/exceptions'
require 'tm_sync/command'

module TmSync

  class RequestHandler

    attr_reader :base_uri
    attr_accessor :connection_manager

    def initialize(base_uri)
      @base_uri = base_uri
    end

    def connect(remote_url, client_id, auth_token)
      conn = DatagramConnection.new(remote_url)

      command = Command::Register.new
      command.url = connection_manager.receive_url
      command.client_id = client_id
      command.auth_token = auth_token
      command.slave_token = connection_manager.create_token
      command.version = TmSync::PROTOCOL_VERSION
      command.flags = TmSync::SUPPORTED_PROTOCOL_FLAGS

      response = connection_manager.send_command(command, conn)
      case response.response_code
        when 200
          connection = connection_manager.create_connection(
              remote_url,
              command.slave_token,
              response[:'master-token'],
              response[:flags]
          )
          connection.state = ConnectionState::INITIALIZED
        when 401
          raise InvalidCredentialsException.new('Invalid credentials')

        when 400
          raise RemoteVersionUnsupported.new('Remote host does not support this TM-Sync version')

        else
          raise UnexpectedResponseException.new("Unexpected response-code of client: #{response.response_code}")
      end
    end

    def accept(request, response)
      if TmSync::PROTOCOL_VERSION != request.command.version
        response.response_code = 400
        response.error = "Version mismatch #{request.command.verison} => #{TmSync::PROTOCOL_VERSION}"
        response.payload = {}
        return
      end

      flags = request.command.flags & TmSync::SUPPORTED_PROTOCOL_FLAGS
      token = connection_manager.create_token

      connection = connection_manager.create_connection(
        request.command.url,
        token,
        request.command.slave_token,
        flags
      )

      send_handshake(ConnectionState::INITIALIZED, connection)

      response.payload = {
          'master-token' => token,
          'version'      => TmSync::PROTOCOL_VERSION,
          'flags'        => flags
      }
    end

    def receive_message(request, &block)
      connection_manager.receive(request) do |request, response|
        receive(request.command, response, &block)
      end
    end

    def receive(command, response)
      if response.connection.state == ConnectionState::INITIALIZED
        handshake_prepare(command, response)
      end

      yield command, response if block_given?
    end

    def defer_send(connection, command)
      defer do
        response = connection_manager.send_command(command, connection)
        yield response if block_given?
      end
    end

    def defer(&block)
      connection_manager.defer do
        block.()
      end
    end

    private
    def handshake_prepare(command, response)
      connection = response.connection

      if not [:push, :register].include? command.name
        connection.state = ConnectionState::BROKEN
        raise ConnectionBrokenException.new
      end

      send_handshake(ConnectionState::OPEN, connection)
      response.payload = {'synced-objects' => 0}
    end

    def send_handshake(new_state, connection)
      acknowledge = TmSync::Command::Push.new
      acknowledge.payload = []

      connection.state = new_state
      ::Rails.logger.info connection.outbound_connection.inspect
      defer_send connection, acknowledge
    end

  end

end