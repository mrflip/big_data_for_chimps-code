# -*- coding: utf-8 -*-
module Rucker

  class Container < Rucker::Manifest::Base
    field :name,         :symbol
    field :image_name,   :string
    field :hostname,     :string, doc: "the desired hostname to use for the container"
    #
    field :entrypoint,   :string
    field :volumes_from, :array, of: :string, default: ->{ [] }
    field :volumes,      :array, of: :string, default: ->{ [] }
    field :links,        :array, of: :string, default: ->{ [] }
    field :exposes,      :array, of: :string, default: ->{ [] }
    field :envs,         :array, of: :string, default: ->{ [] }
    field :entry_args,   :array, of: :string, default: ->{ [] }
    #
    collection :ports,   Rucker::PortBindingCollection, item_type: PortBinding
    field :docker_obj,   Whatever

    def state
      return :absent if self.docker_obj.blank?
      docker_obj.state
    end

    #
    # Orchestration movements
    #

    def ready
      case state
      when :running then              return true
      when :paused  then              return true
      when :stopped then              return true
      when :restart then              return false # wait for restart
      when :absent  then _create  ;   return false # wait for create
      else return false # don't know, hope we figure it out.
      end
    end

    def up
      case state
      when :running then              return true
      when :paused  then _unpause ;   return false # wait for unpause
      when :stopped then _start   ;   return false # wait for start
      when :restart then              return false
      when :absent  then ready    ;   return false # wait for ready
      else return false # don't know, hope we figure it out.
      end
    end

    def down
      case state
      when :running then _stop   ;    return false # wait for stop
      when :paused  then _stop   ;    return false # wait for stop
      when :stopped then              return true
      when :restart then              return false # wait for restart
      when :absent  then              return true
      else return false # don't know, hope we figure it out.
      end
    end

    def clear
      case state
      when :running then down ;       return false # wait for down
      when :paused  then down ;       return false # wait for down
      when :stopped then _remove    ; return false # wait for remove
      when :restart then              return false
      when :absent  then            ; return true
      else return false # don't know, hope we figure it out.
      end
    end

    #
    # Procedural actions
    #

    # Creates a container rfomr the specified image and prepares it for
    # running the specified command. You can then start it at any point.
    def _create
      Rucker.progress("  Creating #{type_name} #{name}")
      self.docker_obj = Docker::Container.create_from_manifest(self)
      forget() ; self
    end

    # Start a created container
    def _start
      Rucker.progress("  Starting #{type_name} #{name}")
      docker_obj.start_from_manifest(self)
      forget() ; self
    end

    # Stop a running container by sending `SIGTERM` and then `SIGKILL` after a grace period
    def _stop
      Rucker.progress("  Stopping #{type_name} #{name}")
      docker_obj.stop_from_manifest(self)
      forget() ; self
    end

    # Remove a container completely.
    def _remove
      Rucker.progress("  Removing #{type_name} #{name}")
      docker_obj.remove('v' => 'true')
      forget() ; self
    end

    # Pause all processes within a container. The docker pause command uses the cgroups freezer to suspend all processes in a container. Traditionally when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended. With the cgroups freezer the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
    def _pause()
      Rucker.progress("  Pausing #{type_name} #{name}")
      docker_obj.pause()
      forget() ; self
    end
    # The docker unpause command uses the cgroups freezer to un-suspend all processes in a container.
    def _unpause()
      Rucker.progress("  Unpausing #{type_name} #{name}")
      docker_obj.pause()
      forget() ; self
    end

    # Display the running processes of a container. Options are passed along to PS.
    def top(opts={})
      Rucker.progress("  Showing #{type_name} #{name}'s top processes")
      Rucker.output( docker_obj.top(opts) )
    end

    def forget
      docker_obj.forget if docker_obj.present?
      self
    end

    # used by KeyedCollection to know how to index these
    def collection_key()        name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key(key) receive_name(key) ; end
  end

  class ContainerCollection < Rucker::KeyedCollection
    include Rucker::Common
    MAX_RETRIES = 10

    def invoke_until_satisfied(operation)
      MAX_RETRIES.times do |idx|
        Rucker.progress("Group is #{state_desc}")
        Rucker.progress("#{operation} -> #{length} #{item_type.type_name}#{idx > 1 ? " (#{idx})" : ''}")
        successes = items.map do |ctr|
          begin
            ctr.public_send operation
          rescue Docker::Error::DockerError => err
            warn "Problem with #{operation} -> #{ctr.name}: #{err}"
            sleep 1
          end
        end
        return true if successes.all? # we caused no changes in the world, so don't need to refresh
        sleep 1.5
        refresh!
      end
      Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{MAX_RETRIES} attempts. Dying."
    end

    #
    # State managemet
    #

    def state
      each_value.map(&:state).uniq.compact
    end
    def running?() state == [:running] ; end
    def paused?()  state == [:paused]  ; end
    def stopped?() state == [:stopped] ; end
    def restart?() state == [:restart] ; end
    def absent?()  state == [:absent]  ; end
    def consistent?() state.length == 1 ; end

    def refresh!
      # Reset all the containers and get a lookup table of containers
      each{|ctr| ctr.forget ; ctr.unset_attribute(:docker_obj) }
      #
      # Grab all the containers
      #
      ctr_names = keys.to_set
      Docker::Container.all('all' => 'True').map do |docker_obj|
        # any of the names match a manifest?
        name = ctr_names.intersection(docker_obj.names).first or next
        # great, gift the docker_obj to the manifest
        self[name].docker_obj = docker_obj
      end
      self
    end
    #
  end

  class Cluster < Rucker::Manifest::Base
    field :name, :symbol
    collection :containers, Rucker::ContainerCollection, item_type: Rucker::Container
    #
    def container(name)   containers[name.to_sym] ; end
    def container_names() containers.keys ; end

    def image_names()     containers.map(&:image_name).uniq ;  end

    #
    # Info
    #

    # @return [Array[Symbol]] a sorted list of all states seen in the cluster.
    def state
      containers.state
    end

    #
    # Machinery
    #

    def containers_slice(ctr_names, opts={})
      return containers.to_a if ctr_names.to_s == 'all'
      containers.slice(*check_container_keys(ctr_names, opts))
    end

    def check_container_keys(ctr_names, opts={})
      return containers.keys if ctr_names.to_s == 'all'
      ctr_names = Array.wrap(ctr_names).map(&:to_sym)
      unless opts[:ignore_extra] || containers.all_present?(ctr_names) then warn("Keys #{containers.extra_keys(ctr_names)} aren't present in this cluster, skipping") ; end
      (ctr_names & containers.keys) # intersection
    end

    # used by KeyedCollection to know how to index these
    def collection_key()        name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key(key) receive_name(key) ; end
  end

  class ClusterCollection < KeyedCollection
  end

  class World < Rucker::Manifest::Base
    include Gorillib::Model
    field :name, :symbol, default: :world
    #
    collection :clusters,  ClusterCollection, item_type: Rucker::Cluster
    collection :images,    ImageCollection,   item_type: Rucker::Image

    def self.load(name)
      layout = YAML.load_file Pathname.of(:cluster_layout)
      world_layout = layout[name.to_s]
      world_layout['clusters'] = world_layout['clusters'].map{|cl_name, ctrs| { name: cl_name, containers: ctrs } }
      receive(world_layout).refresh!
    end

    def refresh!
      all_containers.refresh!
      self
    end

    def image_names(cl_names='all')
      clusters_slice(cl_names).map(&:image_names).flatten.uniq
    end

    #
    #
    #

    def cluster(name) clusters.find{|cl| cl.name == name } ; end
    #
    def clusters_slice(cl_names)
      return clusters if cl_names.to_s == 'all'
      Array.wrap(cl_names).map do |cl_name|
        cluster(cl_name) or abort("Can't find cluster #{cl_name} in #{self.inspect}")
      end
    end

    def all_containers
      return @all_containers if instance_variable_defined?(:@all_containers)
      @all_containers = Rucker::ContainerCollection.new(item_type: Rucker::Container)
      clusters.each do |cl|
        cl.containers.each{|cnt| @all_containers.add(cnt) }
      end
      @all_containers
    end

    def container(name)
      clusters.map{|cl| cl.container(name) }.compact.first
    end
    #
    # @param names [String] names of containers to retrieve, or 'all' for all.
    # @return [Array[Rucker::Layour::Container]] requested containers across all clusters
    def containers_slice(names)
      clusters.map{|cl| cl.containers_slice(names, ignore_extra: true).to_a }.flatten.compact
    end

    # #
    # # @return [Hash[Rucker::Layour::Container]] Hash of name => container for all defined containers
    # def containers_hsh
    #   hsh = {}
    #   clusters.each{|cl| cl.containers.each{|ctr| hsh[ctr.name] = ctr } }
    #   hsh
    # end

    # @return [Array[Symbol]] a sorted list of all states seen in the world.
    def state
      clusters.map{|cl| cl.state }.flatten.uniq.sort
    end
  end

end
