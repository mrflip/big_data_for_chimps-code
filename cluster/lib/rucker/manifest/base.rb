module Rucker

  module Manifest

    module HasState
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

      #
      # States
      #

      def running?() Array.wrap(state) == [:running] ; end
      def paused?()  Array.wrap(state) == [:paused ] ; end
      def stopped?() Array.wrap(state) == [:stopped] ; end
      def restart?() Array.wrap(state) == [:restart] ; end
      def absent?()  Array.wrap(state) == [:absent ] ; end

      def consistent?() Array.wrap(state).length == 1 ; end
    end

    class Base
      include Gorillib::Model
      # include Gorillib::Model::PositionalFields

      def self.collection(field_name, collection_type, opts={})
        item_type = opts[:item_type] = opts.delete(:of) if opts.has_key?(:of)
        opts = opts.reverse_merge(
          default: ->{ collection_type.new(item_type: item_type, belongs_to: self) } )
        fld = field(field_name, collection_type, opts)
        define_collection_receiver(fld)
        fld
      end

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
        Rucker.warn "Extra attributes: #{attrs.keys}" if attrs.present?
        super
      end

      # used by KeyedCollection to know how to index these
      def collection_key()        name ; end
      # used by KeyedCollection to know how to index these
      def set_collection_key(key) receive_name(key) ; end
    end

  end
end
