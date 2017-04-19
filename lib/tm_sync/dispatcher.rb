require 'tm_sync/core/handler'

module TmSync

  module CommandSender

    def connect(*args)
      @handler.connect(*args)
    end

    def push(connection, objects)
      push = TmSync::Command::Push.new
      push.payload = object.map &query_manager.method(:convert_obj)
      @handler.send_message(connection, push)
    end

    def pull(connection, type, query = {})
      pull = TmSync::Command::Pull.new
      pull.type = type
      pull.query = query
      @handler.send_message(connection, pull)
    end

    def notify(connection, command, data)
      notify = TmSync::Command::Notify.new
      notify.command = command
      notify.data = data
      @handler.send_message(connection, notify)
    end

  end

  module Dispatcher
    def before(&block)
      @before_filters << block
    end

    def notified(&block)
      @notified_filters << block
    end

    def receive(request)
      @handler.receive_message(request) do |command, response|
        @before_filters.each do |filter|
          return if not filter.(request, response)
        end
        dispatch(request, response)
      end
    end

    def dispatch(request, response)
      if respond_to? :"handle_#{request.command.name}"
        send(:"handle_#{request.command.name}", request, response)
      else
        handle_default(request, response)
      end
    end

    def handle_register(request, response)
      handler.accept(request, response)
    end

    def handle_push(request, response)
      sync_manager.synchronize(request.command, response)
    end

    def handle_pull(request, response)
      response.payload = query_manager.query(request.command, response)
    end

    def handle_notify(request, response)
      response.payload = nil

      case request.type
        when :register
          handler.defer do
            handler.connect(
                request.data['url'],
                request.data['master-client-id'],
                request.data['master-client-token']
            )
          end

          response.payload = {'token' => ''}

        when :push
          fake_pull = TmSync::Command::Pull.new
          fake_pull.payload = request.command.data
          q = query_manager.query(fake_pull, nil)
          notify_response(:push, push(request.connection, q))

        when :pull
          notify_response(:pull, pull(request.data['type'], request.data['query']))
      end

      response.state = :accepted
      response.payload = {} if response.payload.nil?
    end

    def handle_default(request, response)
      response.response_code = 501
      response.error = "Command not implemented"
      response.payload = {}
    end

    private
    def notify_response(q, response)
      notified_filters.each do |filter|
        filter.(:pull, response)
      end
    end
  end

  class Client
    include Dispatcher
    include CommandSender

    attr_reader :handler
    attr_accessor :sync_manager
    attr_accessor :query_manager

    def initialize(base_uri, manager)
      @handler = RequestHandler.new(base_uri)
      @handler.connection_manager=manager

      @before_filters = []
      @notified_filters = []
    end



  end

end