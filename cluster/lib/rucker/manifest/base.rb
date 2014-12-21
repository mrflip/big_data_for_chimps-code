module Rucker

  module Manifest

    module HasState
      def state_desc
        states = Array.wrap(state).flatten.uniq
        case
        when states == []       then "missing anything to report state of"
        when states.length == 1 then states.first.to_s
        else
          fin = states.pop
          "a mixture of #{states.join(', ')} and #{fin.to_s} states"
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

      def consistent?() Array.wrap(state).flatten.uniq.length == 1 ; end
    end

    class Base
      include Gorillib::Model
      include Gorillib::AccessorFields

      def handle_extra_attributes(attrs)
        super
        Rucker.warn "Extra attributes: #{attrs.keys}" if attrs.present?
      end


      def self.type_name
        Gorillib::Inflector.demodulize(name.to_s)
      end
      def type_name() ; self.class.type_name ; end

      def desc
        "#{type_name} #{name}"
      end

      # used by KeyedCollection to know how to index these
      def collection_key()        name ; end
      # used by KeyedCollection to know how to index these
      def set_collection_key(key) receive_name(key) ; end
    end

  end
end
