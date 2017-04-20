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
        actual_params = JSON.parse(
            request.raw_post.encode("utf-8"),
        ).with_indifferent_access

        request = TmSync::Rails::RailsRequest.new(self)
        request.sequence_number = actual_params[:sequence].to_i
        request.token = actual_params[:token]
        request.command = Command.create(actual_params[:command].to_sym, actual_params[:payload])
        request
      end

    end

  end

end