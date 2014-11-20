module Rucker
  module Common

    def state_desc
      states = Array.wrap(state)
      case
      when states == []       then "missing anything to report state of"
      when states.length == 1 then states.first.to_s
      else
        fin = states.pop
        "a mixture of #{states.join(', ')} and #{fin} states"
      end
    end

  end

  module Manifest
    class Base
      include Gorillib::Model
      include Rucker::Common
      # include Gorillib::Model::PositionalFields

      class_attribute :accessor_fields
      self.accessor_fields = []

      def self.type_name
        Gorillib::Inflector.demodulize(name.to_s)
      end

      def type_name
        self.class.type_name
      end

      def desc
        "#{type_name} #{name}"
      end

      def self.accessor_field(name, type=Whatever, opts={})
        name = name.to_sym
        attr_accessor name
        self.accessor_fields += [name]
      end

      def handle_extra_attributes(attrs)
        accessor_fields.each do |fn|
          instance_variable_set(:"@#{fn}", attrs.delete(fn)) if attrs.include?(fn)
        end
        warn "Extra attributes: #{attrs.keys}" if attrs.present?
        super
      end

    end

  end
end
