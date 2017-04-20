module TmSync

  class Command

    attr_accessor :payload

    def name
      raise RuntimeError.new('No name given')
    end

    class << self
      module ClassMethods

        def payload(*payloads)
          payloads.each do |payload|
            if not payload.is_a? Hash
              define_method payload do
                self.payload[payload.to_s]
              end

              define_method :"#{payload}=" do |value|
                self.payload[payload.to_s] = value
              end
            else
              payload.each do |p_method_name, p_payload_name|
                define_method p_method_name do
                  self.payload[p_payload_name.to_s]
                end
                define_method :"#{p_method_name}=" do |value|
                  self.payload[p_payload_name.to_s] = value
                end
              end
            end
          end
        end

        def with_name(name)
          Command.commands[name] = self

          define_method :name do
            name
          end

          define_singleton_method :command_name do
            name
          end
        end
      end
      extend ClassMethods

      def commands
        @commands ||= {}
      end

      def create(name, payload=nil)
        result = (commands[name] || raise(RuntimeError.new("Can't find command #{name}"))).new
        result.payload = payload if not payload.nil?
        result
      end

      def to_h
        result.payload || {}
      end

      def inherited(klass)
        klass.extend ClassMethods
      end

    end

  end


  class Command
    class Register < Command
      with_name :register

      payload :url
      payload :client_id => 'client-id'
      payload :auth_token => 'auth-token'
      payload :slave_token => 'slave-token'
      payload :version
      payload :flags
    end

    class Notify < Command
      with_name :notify
      payload :command, :data
    end

    class Push < Command
      with_name :push
    end

    class Pull < Command
      with_name :pull

      payload :type
      payload :query
    end

    class Subscribe < Command
      with_name :subscribe

      payload :pull_query => 'pull-query'
      payload :method
    end

    class Unsubscribe < Command
      with_name :unsubscribe

      payload :subscription_id => 'subscription-id'
    end
  end

end