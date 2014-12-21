module Rucker
  module Actual

    require 'singleton'
    class Boot2dNode
      include Singleton

      def up?()         true ; end
      def ready?()      true ; end
      def down?()       true ; end
      def absent?()     false ; end
      def clear?()      false ; end
      def transition?() false ; end

      def state
        :running
      end

      def forget
      end

      def refresh!
      end

      def self.create_using_manifest(mft)
        self.instance
      end

      def start_using_manifest(mft)
        self
      end

      def stop_using_manifest(mft)
        self
      end

      def remove_using_manifest(mft)
        self
      end

      def self.actualize_manifests(coll)
        coll.each{|mft| mft.actual = self.instance }
      end

    end

  end
end
