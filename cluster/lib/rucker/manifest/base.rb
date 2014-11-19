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

      class_attribute :skip_serialization_of
      self.skip_serialization_of = [:docker_obj].to_set

      def self.type_name
        Gorillib::Inflector.demodulize(name.to_s)
      end

      def type_name
        self.class.type_name
      end

      def desc
        "#{type_name} #{name}"
      end

      def handle_extra_attributes(attrs)
        warn "Extra attributes: #{attrs.keys}" if attrs.present?
        super
      end

      def to_wire(options={})
        compact_attributes.merge(:_type => self.class.typename).inject({}) do |acc, (key,attr)|
          next(acc) if skip_serialization_of.include?(key)
          acc[key] = attr.respond_to?(:to_wire) ? attr.to_wire(options) : attr
          acc
        end
      end
    end

  end
end
