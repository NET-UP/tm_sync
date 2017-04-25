require 'digest/sha2'

module TmSync

  module SyncManager
    def receive(name, &block)
      @types ||= Hash.new{|hash, key| hash[key] = ->object, mode{false}}
      @types[name] = block
    end

    def synchronize(command, request=nil)
      request = TmSync::Request.new if request.nil?
      synced = 0

      command.payload.each do |object|
        identifier = object['identifier']
        type = object['type'].to_sym
        mode = object['mode'].to_sym
        checksum = object['checksum']

        data = object['object']

        if Digest::SHA2.new(512).hexdigest(data.to_json.encode('utf-8')) != checksum
          request.response_code = 422
          request.error = 'Checksum mismatch detected'
          request.payload = {type: type, identifier: identifier}
          return
        elsif identifier != data['identifier']
          request.response_code = 400
          request.error = 'Identifier mismatch detected'
          request.payload = {type: type, identifier: identifier}
          return
        end

        if @types[type].(data, mode)
          synced += 1
        end
      end

      request.payload = {synced_object: synced}
    end
  end

end