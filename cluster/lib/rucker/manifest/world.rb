# -*- coding: utf-8 -*-
module Rucker
  module Manifest
    class World < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
      field :name,        :symbol
      field :layout_file, :string
      field :provider,    :symbol, default: :docker
      #
      collection :images,      Rucker::Manifest::ImageCollection
      collection :nodes,       Rucker::Manifest::NodeCollection
      collection :services,    Rucker::Manifest::ContainerCollection
      collection :extra_ports, Rucker::Manifest::PortBindingCollection
      def containers() services ; end

      # Loads the chosen world from the layout yaml file
      # @return Rucker::Manifest::World
      def self.load(layout_file, name)
        layout = YAML.load_file layout_file
        world_layout = layout[name.to_s]
        world_layout['name'] = name
        world_layout['layout_file'] = layout_file
        world = receive(world_layout)
        world.containers.each do |ctr|
          ctr.image = world.images[ctr.image_name] or Rucker.warn "No image '#{ctr.image_name}' defined for container #{ctr}. Check #{layout_file}"
        end
        world
      end

      def refresh!
        nodes.refresh!
        images.refresh!
        containers.refresh!
        self
      end

      #
      # Actions
      #

      def up?()        images.up?    && nodes.up?    && containers.up?    ; end
      def ready?()     images.ready? && nodes.ready? && containers.ready? ; end
      def down?()                       nodes.down?  && containers.down?  ; end
      def clear?()                      nodes.clear? && containers.clear? ; end

      def up
        self.ready
        images.up
        nodes.up
        containers.up
      end

      def ready
        images.up
        containers.ready
        nodes.ready
      end

      def down
        containers.down
        nodes.down
      end

      def clear
        self.down
        containers.clear
        nodes.clear
      end

      #
      # Slicing
      #

      # @return [Rucker::Manifest::Container] the named container, or nil
      def container(name)  containers[name] ; end

      # @return [Rucker::Manifest::Image] the named image, or nil
      def image(name)      images[name] ; end

      # @return [Rucker::Manifest::Node] the named node, or nil
      def node(name)       nodes[name]  ; end

      def ports
        ports_coll = Rucker::Manifest::PortBindingCollection.new(belongs_to: self)
        ports_coll.receive!( extra_ports.items )
        containers.each do |ctr|
          ports_coll.receive!( ctr.ports.items )
        end
        ports_coll
      end

      # @return [Array[Symbol]] a sorted list of all states seen in the world.
      def state
        [ images.map{|obj|     obj.state }.flatten.uniq.sort,
          nodes.map{|obj|      obj.state }.flatten.uniq.sort,
          containers.map{|obj| obj.state }.flatten.uniq.sort, ]
      end

      # # @return [Rucker::Manifest::Cluster] the named cluster, or nil
      # def cluster(name)    clusters[name] ; end
      #
      # # @return [Rucker::Manifest::ClusterCollection] the named clusters
      # def clusters_slice(cl_names)
      #   clusters.slice(*cl_names)
      # end
      #
      # # @return [Rucker::Manifest::ImageCollection] the named images
      # def images_slice(img_names)
      #   images.slice(*img_names)
      # end
      #
      # # @return [Rucker::Manifest::ContainerCollection] the named containers
      # def containers_slice(names)
      #   containers.slice(*names)
      # end
      #
      # def containers
      #   return @containers if instance_variable_defined?(:@containers)
      #   @containers = Rucker::Manifest::ContainerCollection.new(belongs_to: self)
      #   clusters.each do |cl|
      #     cl.containers.each{|cnt| @containers.add(cnt) }
      #   end
      #   @containers
      # end

      @authentication_mutex = Mutex.new

      class << self
        def credentials()
          return @credentials if instance_variable_defined?(:@credentials)
          docker_creds = File.expand_path(ENV['DOCKER_CREDENTIALS'] || '~/.docker_credentials')
          raise "docker credentials file doesn't exist" if not File.exists?(docker_creds)
          #
          @credentials = MultiJson.load(File.read(docker_creds))
          @credentials
        rescue StandardError => err
          raise err.class, "Could not load credentials from #{docker_creds}: #{err.message}.", err.backtrace
        end
        protected :credentials

        def unset_credentials
          remove_instance_variable(:@credentials) if instance_variable_defined?(:@credentials)
        end

        #
        # To use this, create a JSON file named '$HOME/.docker_credentials'
        # with the following structure:
        #
        #      { "index.docker.io":{
        #        "serveraddress":"https://index.docker.io/v1/",
        #        "username":"bob",
        #        "email":"bob@dobbs.com",
        #        "password":"monkey"}
        #      }
        #
        #
        def authenticate!(registry)
          creds_hsh = nil
          @authentication_mutex.synchronize do
            registry = registry.to_s
            creds_hsh = credentials[registry] or raise "No credentials for '#{registry}' present in loaded credentials: #{creds_list.keys}"
            return creds_hsh if creds_hsh[:docker_str].present?
            #
            Rucker.progress(:authing, self, to: registry)
            Docker.authenticate!(creds_hsh)
            creds_hsh[:docker_str] = Docker.creds
          end
          creds_hsh
        end
      end

    end
  end
end
