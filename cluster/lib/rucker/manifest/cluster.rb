module Rucker
  module Manifest

    class Cluster < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
      field :name, :symbol
      accessor_field :world
      collection :containers, Rucker::Manifest::ContainerCollection
      #
      def container(name)   containers[name.to_sym] ; end
      def container_names() containers.keys ; end

      def image_names()     containers.map(&:image_name).uniq ;  end

      def images()
        world.images_slice(image_names)
      end

      def up?()        containers.all?(&:up?)    ; end
      def ready?()     containers.all?(&:ready?) ; end
      def down?()      containers.all?(&:down?)  ; end
      def clear?()     containers.all?(&:clear?) ; end

      def up(*args)    containers.up(*args)    ; end
      def ready(*args) containers.ready(*args) ; end
      def down(*args)  containers.down(*args)  ; end
      def clear(*args) containers.clear(*args) ; end

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
