require 'tm_sync/utils'

module TmSync

  class Response
    include JSONAble

    attr_accessor :response_code, :error, :payload
    attr_accessor :request

    def send!
      request.respond! self
    end

    def connection
      request.connection
    end

    def to_h
      result = {
          :response_code => response_code,
          :payload => payload.to_h
      }

      result[:error] = error if not error.nil?
      result
    end

    def [](value)
      payload[value]
    end

  end

end