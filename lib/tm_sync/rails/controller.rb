require 'tm_sync/rails/request'
module TmSync

  module Rails

    module SyncController

      def self.request_handler(name)
        define_method name do
          begin
            client.receive(build_request)
          rescue => e
            Rails.logger.error "#{e.class.to_s}: #{e.to_s}"
            e.backtrace.each {|line| Rails.logger.error line}
            render :test => "Something went wrong.", :layout => false, :status => 500
          end
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
            request.raw_post.force_encoding("utf-8"),
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