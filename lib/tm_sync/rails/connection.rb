require 'tm_sync/utils'

module TmSync

  module Rails

    class Channel < ActiveRecord::Base
      include TmSync::HalfDuplexConnection
      include LazyAliasMethod

      def token
        self[:token]
      end

      lazy_alias_method :is_sending?, :outbound

      belongs_to :connection

      def is_receiving?
        !is_sending
      end

      def lock_connection(&block)
        with_lock(true, &block)
      end

      def increment_sequence_number
        current = sequence_number
        increment(:sequence_number)
        save!
        current
      end
    end

    class Connection < ActiveRecord::Base
      include TmSync::Connection

      include LazyAliasMethod

      if ::Rails.version > "6"
        has_one :outbound_connection,
                ->{where outbound: true},
                as: :channel

        has_one :inbound_connection,
                ->{where outbound: false},
                as: :channel
      else
        has_one :outbound_connection,
                ->{where outbound: true},
                :foreign_type => :channel

        has_one :inbound_connection,
                ->{where outbound: false},
                :foreign_type => :channel
      end

      def endpoint
        self[:endpoint]
      end

      # WARNING: BUG. Manually define
      # outbound_connection and inbound_connection

      def state
        ConnectionState.by_name(self.connection_state)
      end

      def state=(value)
        self.connection_state = value.name
        save!
      end

      def datagram?
        false
      end

    end

    module RailsConnectionManager
      include TmSync::ConnectionManager

      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods

        attr_accessor :connection_class
        attr_accessor :channel_class

        def create_token(&block)
          @create_token = block
        end

        def defer(&block)
          @defer = block
        end

        def _get_create_token
          @create_token
        end

        def _get_defer
          @defer
        end

      end

      def create_token
        self.class._get_create_token.()
      end

      def defer(&block)
        self.class._get_defer.(&block)
      end

      def find_connection_by_token(token)
        value = super
        return value if value
        channel = self.class.channel_class.where(token: token).where(outbound: false).first
        return nil if channel.nil?
        channel.connection
      end

      def create_connection(uri, local_token, remote_token, flags)
        self.class.connection_class.transaction do
          connection = self.class.connection_class.new
          connection.endpoint = uri
          connection.state = ConnectionState::INITIALIZED
          connection.save!

          outbound_connection = self.class.channel_class.new
          outbound_connection.token = remote_token
          outbound_connection.outbound = true
          outbound_connection.sequence_number = 0
          outbound_connection.connection = connection
          outbound_connection.save!

          inbound_connection = self.class.channel_class.new
          inbound_connection.token = local_token
          inbound_connection.outbound = false
          inbound_connection.sequence_number = 0
          inbound_connection.connection = connection
          inbound_connection.save!

          connection
        end

      end
    end

  end

end
