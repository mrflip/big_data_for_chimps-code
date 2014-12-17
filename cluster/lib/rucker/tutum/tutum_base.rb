module Rucker
  module Tutum
    class TutumBase
      include Gorillib::Model
      include Gorillib::AccessorFields

      def self.connection
        @connection ||=
          begin
            creds = Rucker::Manifest::World.send(:credentials)['tutum.co']
            creds.present? && creds['api_key'].present? or raise ArgumentError, "No API key found in the credentials file. See Rucker::Manifest::World.credentials"
            ::Tutum.new(creds['username'], creds['api_key'])
          end
      end
      def connection() self.class.connection ; end


      attr_reader :raw_attrs
      def receive!(*args, &blk)
        @raw_attrs = args.first.dup
        super
      end

    end
  end
end
