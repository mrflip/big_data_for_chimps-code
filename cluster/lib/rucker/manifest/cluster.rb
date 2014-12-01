module Rucker
  module Manifest

    class Cluster < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
      field :name, :symbol
      # accessor_field :world
      collection :containers, Rucker::Manifest::ContainerCollection
      #
      def container(name)   containers[name.to_sym] ; end
      def container_names() containers.keys ; end

      def image_names()     containers.map(&:image_name).uniq ;  end

      def world
        Rucker.world
      end

      def images()
        world.images.slice(*image_names)
      end

      def up?()        containers.items.all?(&:up?)    ; end
      def ready?()     containers.items.all?(&:ready?) ; end
      def down?()      containers.items.all?(&:down?)  ; end
      def clear?()     containers.items.all?(&:clear?) ; end

      def up
        images.ready
        containers.ready
        containers.up
      end

      def ready
        images.ready
        containers.ready
      end

      def down
        containers.down
      end

      def clear
        containers.clear
      end

      #
      # Info
      #

      # @return [Array[Symbol]] a sorted list of all states seen in the cluster.
      def state
        containers.state
      end

      def refresh!
        containers.refresh!
        self
      end

      def containers_slice(names='all', opts={})
        containers.slice(*names)
      end

    end

    class ClusterCollection < Rucker::KeyedCollection
      self.item_type = Rucker::Manifest::Cluster
    end

  end
end
