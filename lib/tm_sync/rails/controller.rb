require 'tm_sync/rails/request'
module TmSync

  module Rails

    module SyncController

      def self.request_handler(name)
        define_method name do
          client.receive(build_request)
        end
      end

      request_handler :notify
      request_handler :register
      request_handler :push
      request_handler :pull
      request_handler :subscribe
      request_handler :unsubscribe

      ##
      # Catch All request handler
      request_handler :sync

      protected
      def client

      end

      private
      def build_request
        request = TmSync::Rails::RailsRequest.new(self)
        request.sequence_number = params[:sequence].to_i
        request.token = params[:token]
        request.command = Command.create(params[:command].to_sym, params[:payload])
        request
      end

    end

  end

end