begin
  require 'redis'
  require 'uuidtools'
rescue LoadError => e
  if require 'rubygems' then retry
  else raise(e)
  end
end

module RedRed
  class <<self
    def read_attr(object, name)
      save_value = connection.get([object.redis_id, 'attr', name].join('/'))
      type, value = /^(.)(.+)$/.match(save_value).to_a[1..-1]
      case type
      when 'r'
        class_name, id = /^([^ ]+) (.+)$/.match(value).to_a[1..-1]
        full_const_get(class_name)[id]
      when 's'
        Marshal.load(value)
      end
    end

    def write_attr(object, name, value)
      key = [object.redis_id, 'attr', name].join('/')
      save_value = 
        if value.respond_to?(:redis_id)
          "r#{value.class.name} #{value.redis_id}"
        else
          "s#{Marshal.dump(value)}"
        end
      connection.set(key, save_value)
      value
    end

    private

    def connection
      @connection ||= Redis.new
    end

    def full_const_get(name)
      name.split('::').inject(Object) do |ns, const|
        ns.const_get(const)
      end
    end
  end

  class Object
    class <<self
      def rattr_accessor(*names)
        names.each do |name|
          module_eval(<<-RUBY)
            def #{name}
              @#{name} ||= RedRed.read_attr(self, #{name.inspect})
            end

            def #{name}=(value)
              @#{name} = RedRed.write_attr(self, #{name.inspect}, value)
            end
          RUBY
        end
      end

      def [](redis_id)
        object = allocate
        object.instance_variable_set(:@redis_id, redis_id)
        object
      end
    end

    def redis_id
      @redis_id ||= UUIDTools::UUID.timestamp_create.to_s
    end
  end
end
