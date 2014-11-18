module Rucker
  module Common

    def state_desc
      states = Array.wrap(state)
      case
      when states == []       then "missing anything to report state of"
      when states.length == 1 then "uniformly #{states.first}"
      else
        fin = states.pop
        "a mixture of #{states.join(', ')} and #{fin} states"
      end
    end

  end
  module Manifest

    class Base
      include Gorillib::Model
      include Gorillib::Model::PositionalFields
      include Rucker::Common

      def self.type_name
        Gorillib::Inflector.demodulize(name.to_s)
      end

      def type_name
        self.class.type_name
      end
    end


  end

end
