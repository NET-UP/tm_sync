module TmSync

  class Enum

    def self.inherited(klass)
      klass.extend ClassMethods
      klass.instance_eval do
        alias_method :original_new, :new

        def new(*args, &block)
          raise RuntimeError.new('Cannot instantiate new enum values')
        end
      end
    end

    module ClassMethods

      def value(name, *args, &block)
        val = original_new(*args, &block)
        def val.name
          name
        end

        const_set(name, val)
      end


    end

  end

end