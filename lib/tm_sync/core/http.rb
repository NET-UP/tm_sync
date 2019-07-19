require 'net/http'

module TmSync

  ##
  # Connection-pooling HTTP-client
  class HttpClient

    attr_reader :base_uri

    def initialize(uri)
      @base_uri = URI(uri)
    end

    def http_client
      HttpClient.for_host(@base_uri.to_s)
    end

    def send(command, limit=10)
      uri = uri_for_command(command.command.name)
      send!(uri, command, limit)
    end

    def send!(location, command, limit=10)
      raise RuntimeError.new('Too many redirects') if limit <= 0
      location = URI(location) if location.is_a? String

      request = Net::HTTP::Post.new(location)
      request['content-type'] = 'application/json; charset=utf-8'
      request.body = command.to_json.encode('utf-8')

      response = http_client.request(request)
      if response.is_a? Net::HTTPRedirection
        return redirect(command, response, limit-1)
      end
      response
    end

    private
    def redirect(command, response, limit)
      location = URI(response['location'])
      if location.host.nil?
        location.scheme = base_uri.scheme
        location.host = base_uri.host
        location.port = base_uri.port
      end

      next_client = HttpClient.for(location.to_s)
      next_client.send!(URI(location).to_s, command, limit)
    end

    def uri_for_command(name)
      if base_uri.path.end_with? '/' or base_uri.path.length == 0
        result = base_uri.dup
        result.path = base_uri.path + name

        return result
      end

      base_uri
    end

    class << HttpClient

      def for_host(url, key=nil)
        @clients ||= {}
        key = get_link_key(url) if key.nil?
        base_uri = URI(url)

        if not @clients.has_key? key
          http_client = Net::HTTP.new(
            base_uri.host, base_uri.port
          )
          http_client.read_timeout = 600
          http_client.use_ssl = true if base_uri.scheme == 'https'
          http_client.start
          @clients[key] = http_client
        end

        if not (result=@clients[key]).active?
          @clients.delete(key)
          return for_host!(url, key)
        end

        result
      end

      private
      def get_link_key(url)
        uri = URI(url)
        uri.scheme + '://' + uri.host + ':' + uri.port.to_s
      end

    end
  end
end
