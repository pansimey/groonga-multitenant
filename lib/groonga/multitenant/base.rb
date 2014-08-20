module Groonga
  module Multitenant
    class Base
      include ActiveModel::Model
      include ActiveModel::Validations
      include ActiveModel::Serializers::JSON

      class << self
        def establish_connection(spec = {})
          @@groonga = Connection.new(spec)
        end

        def inherited(subclass)
          return if subclass.name.nil?
          subclass.define_column_based_methods
        end

        def define_column_based_methods
          @@columns = @@groonga.column_list(self.name)
          @@value_columns = @@columns.reject(&:index?)
          @@time_columns = @@columns.select(&:time?)
          @@index_column_names = @@columns.select(&:index?).map(&:name)

          @@columns.select(&:persistent?).each do |column|
            define_column_based_method(column)
          end
        end

        def where(params)
          Relation.new(@@groonga, self).where(params)
        end

        def select(*columns)
          Relation.new(@@groonga, self).select(*columns)
        end

        def limit(num)
          Relation.new(@@groonga, self).limit(num)
        end

        def offset(num)
          Relation.new(@@groonga, self).offset(num)
        end

        def all
          Relation.new(@@groonga, self)
        end

        def find(arg)
          records = @@groonga.select(self.name, query: "_key:#{arg}")
          raise 'record not found' unless record = records.first
          self.new(record)
        end

        def count
          @@groonga.select(self.name, limit: 0).count
        end

        private
        def define_column_based_method(column)
          if column.time?
            define_time_range_method(column.name)
          else
            attr_accessor column.name
          end

          nil
        end

        def define_time_range_method(name)
          define_method("#{name}=") do |time|
            case time
            when Time, Integer
              instance_variable_set("@#{name}", time.to_f)
            when Float
              instance_variable_set("@#{name}", time)
            else
              raise TypeError, 'should be Time, Integer or Float'
            end
            time
          end

          define_method(name) do
            sec = instance_variable_get("@#{name}")
            return unless sec
            time = Time.at(sec)
            if timezone = Time.zone
              time.getlocal(timezone.formatted_offset)
            else
              time
            end
          end

          nil
        end
      end

      attr_accessor :_id, :_key
      alias __as_json as_json
      private :__as_json

      def key=(arg)
        @_key = arg
      end

      def persisted?
        !@_id.nil?
      end

      def save
        return false unless self.valid?
        unless @_id.nil?
          @@groonga.delete(self.class.name, id: @_id)
        end
        @created_at = Time.new.to_f
        @@groonga.load(value, self.class.name)
        self
      end

      def attributes
        instance_values
      end

      def as_json(options = nil)
        __as_json(options).reject do |key, _|
          @@index_column_names.include?(key) || key == '_id'
        end
      end

      private
      def value
        hash = self.as_json.merge(raw_timestamp)
        [hash].to_json
      end

      def raw_timestamp
        @@time_columns.reduce({}) do |result, column|
          key = column.name
          value = instance_variable_get("@#{key}")
          result.merge(key => value)
        end
      end
    end
  end
end
