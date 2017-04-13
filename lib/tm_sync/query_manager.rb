module TmSync

  module QueryManager

    def answer(name, &block)
      @query_types ||= Hash.new{|hash, key| hash[key] = ->query{nil}}
      @query_types[name] = block
    end

    def convert(type, &block)
      @response_types ||= Hash.new{|hash, key| hash[key] = ->object{Hash.new}}
      @response_types[type] = block
    end

    def convert_obj(object)
      object.class.ancestors.each do |ancestor|
        next if not @response_types.has_key? ancestor
        return @response_types[ancestor].(object)
      end
    end

    def query(command, response)
      result = @types[command.type].(command.query)
      if result.nil?
        return [] if response.nil?
        response.response_code = 415
        response.error = "#{command.type} is not a supported media type."
        response.payload = []
        return
      end

      result.map &method(:convert_obj)
    end

  end

end