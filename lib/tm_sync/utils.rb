module TmSync

  class Enum

    def self.inherited(klass)
      klass.extend ClassMethods
      klass.singleton_class.instance_eval do
        alias_method :original_new, :new

        def new(*args, &block)
          raise RuntimeError.new('Cannot instantiate new enum values')
        end
      end
    end

    module ClassMethods

      def value(name, *args, &block)
        val = original_new(*args, &block)
        val.instance_eval do
          define_singleton_method :name do
            name
          end
        end

        const_set(name, val)
      end

      def by_name(name)
        const_get(name)
      end


    end

  end

  module LazyAliasMethod

    module ClassMethods

      def lazy_alias_method(new_name, old_name)
        define_singleton_method new_name do |*args, &block|
          __send__(old_name, *args, &block)
        end
      end

    end

    def self.included(klass)
      klass.extend ClassMethods
    end

  end

  module JSONAble

    def to_h
      {}
    end

    def to_json(*args, &block)
      to_h.to_json(*args, &block)
    end

  end

end