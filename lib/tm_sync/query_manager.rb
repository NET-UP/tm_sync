require 'digest/sha2'
module TmSync

  module QueryManager

    def answer(name, &block)
      @query_types ||= Hash.new{|hash, key| hash[key] = ->query{nil}}
      @query_types[name] = block
    end

    def convert(type, &block)
      @response_types ||= Hash.new{|hash, key| hash[key] = ->object{Hash.new}}
      type.each do |t_source, t_type|
        @response_types[t_source] = [t_type, block]
      end
    end

    def convert_obj(object)
      object.class.ancestors.each do |ancestor|
        next if not @response_types.has_key? ancestor
        type, func = @response_types[ancestor]
        return [type, func.(object)]
      end
    end

    def dump(items)
      items.map(&method(:convert_obj)).map do |type, result|
        {
            mode: :create,
            type: type,
            identifier: result[:identifier],
            checksum: Digest::SHA2.new(512).hexdigest(result.to_json.encode('utf-8')),
            object: result
        }
      end
    end

    def query(command, response)
      result = @query_types[command.type.to_sym].(command.query)
      if result.nil?
        return [] if response.nil?
        response.response_code = 415
        response.error = "#{command.type} is not a supported media type."
        response.payload = []
        return
      end

      dump(result)
    end

  end

end