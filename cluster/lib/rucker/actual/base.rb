module Rucker
  module Actual
    class Base
      include Gorillib::Model
      include Gorillib::Model::PositionalFields
      class_attribute :skip_serialization_of
      self.skip_serialization_of = [:docker_obj, :manifest].to_set

      def handle_extra_attributes(attrs)
        warn "Extra attributes: #{attrs.keys}" if attrs.present?
        super
      end

      def to_wire(options={})
        compact_attributes.merge(:_type => self.class.typename).inject({}) do |acc, (key,attr)|
          next if skip_serialization_of.include?(key)
          acc[key] = attr.respond_to?(:to_wire) ? attr.to_wire(options) : attr
          acc
        end
      end

    end
  end
end
