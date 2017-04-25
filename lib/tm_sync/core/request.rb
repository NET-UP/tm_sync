require 'tm_sync/core/http'
require 'tm_sync/core/response'

require 'tm_sync/utils'

module TmSync

  class Request
    include JSONAble

    attr_accessor :token, :sequence_number, :command
    attr_accessor :connection

    def to_h
      {
          :token => token,
          :command => command.name,
          :sequence_number => sequence_number,
          :payload => command.to_h
      }
    end

    def send!
      client = TmSync::HttpClient.new(connection.endpoint)
      raw_response = client.send(self)
      data = JSON.parse(raw_response.read_body)

      response = TmSync::Response.new
      response.response_code = raw_response.code
      response.request = self
      response.error = data['error'] if data.has_key? :error
      response.payload = data['payload']
      response
    end

    def respond!(response)
    end

  end

end