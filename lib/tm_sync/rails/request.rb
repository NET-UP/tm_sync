require 'tm_sync/core/request'

module TmSync

  module Rails

    class RailsRequest < TmSync::Request

      attr_accessor :controller

      def initialize(controller)
        self.controller = controller
      end

      def respond!(response)
        Rails.logger.info response.to_yaml
        controller.render :json => response,
                          :status => response.response_code
      end

    end

  end

end
