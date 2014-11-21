# -*- coding: utf-8 -*-
module Rucker
  module Manifest
    class World < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
      field :name, :symbol, default: :world
      field :layout_file, :string
      #
      collection :clusters,    Rucker::Manifest::ClusterCollection
      collection :images,      Rucker::Manifest::ImageCollection
      collection :extra_ports, Rucker::Manifest::PortBindingCollection

      # Loads the chosen world from the layout yaml file
      # @return Rucker::Manifest::World
      def self.load(layout_file, name)
        layout = YAML.load_file layout_file
        world_layout = layout[name.to_s]
        world_layout['layout_file'] = layout_file
        world_layout['clusters'] = world_layout['clusters'].map do |cl_name, ctrs|
          { world: self, name: cl_name, containers: ctrs }
        end
        world_layout['name'] = name
        receive(world_layout).refresh!
      end

      def refresh!
        remove_instance_variable :@ports if instance_variable_defined?(:@ports)
        images.refresh!
        containers.refresh!
        containers.each{|ctr| ctr.image = images[ctr.image_name] or Rucker.warn "No image '#{ctr.image_name}' defined for container #{ctr}. Check #{layout_file}"}
        self
      end

      #
      # Actions
      #

      def up?()    clusters.all?(&:up?)    ; end
      def ready?() clusters.all?(&:ready?) ; end
      def down?()  clusters.all?(&:down?)  ; end
      def clear?() clusters.all?(&:clear?) ; end

      def up(*args)    clusters.each{|cl|               cl.up(*args)    } ; end
      def ready(*args) clusters.each{|cl|               cl.ready(*args) } ; end
      def down(*args)  clusters.items.reverse.each{|cl| cl.down(*args)  } ; end
      def clear(*args) clusters.items.reverse.each{|cl| cl.clear(*args) } ; end

      #
      # Slicing
      #

      # @return [Rucker::Manifest::Cluster] the named cluster, or nil
      def cluster(name)    clusters[name] ; end

      # @return [Rucker::Manifest::Container] the named container, or nil
      def container(name)  clusters.map{|cl| cl.container(name) }.compact.first ; end

      # @return [Rucker::Manifest::Image] the named  image, or nil
      def image(name)      images[name] ; end

      # @return [Rucker::Manifest::ClusterCollection] the named clusters
      def clusters_slice(cl_names)
        clusters.slice(*cl_names)
      end

      # @return [Rucker::Manifest::ImageCollection] the named images
      def images_slice(img_names)
        images.slice(*img_names)
      end

      # @return [Rucker::Manifest::ContainerCollection] the named containers
      def containers_slice(names)
        containers.slice(*names)
      end

      def containers
        return @containers if instance_variable_defined?(:@containers)
        @containers = Rucker::Manifest::ContainerCollection.new(belongs_to: self)
        clusters.each do |cl|
          cl.containers.each{|cnt| @containers.add(cnt) }
        end
        @containers
      end

      def ports
        return @ports if instance_variable_defined?(:@ports)
        ports_coll = Rucker::Manifest::PortBindingCollection.new(belongs_to: self)
        ports_coll.receive!(extra_ports.items)
        containers.each{|ctr| ports_coll.receive!(ctr.ports.items) }
        ports_coll
      end

      # @return [Array[Symbol]] a sorted list of all states seen in the world.
      def state
        clusters.map{|cl| cl.state }.flatten.uniq.sort
      end

    end
  end
end
