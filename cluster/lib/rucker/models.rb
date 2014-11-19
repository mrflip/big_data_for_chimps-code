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
    #
    attr_accessor :docker_obj
    class_attribute :max_retries; self.max_retries = 10

    def receive!(val)
      if val.respond_to?(:delete)
        @docker_obj = val.delete(:docker_obj)
      end
      super(val)
    rescue
      super(val)
    end

    def state
      return :absent if self.docker_obj.blank?
      docker_obj.state
    end

    def exit_code
      return -999 if self.docker_obj.blank?
      docker_obj..exit_code
    end

    #
    # Orchestration movements
    #

    def invoke_until_satisfied(operation, *args)
      forget
      max_retries.times do |idx|
        begin
          Rucker.progress("#{operation} -> #{desc} (#{state_desc}) #{idx > 1 ? " (#{idx})" : ''}")
          success = self.public_send("_#{operation}", *args)
          return true if success
        rescue Docker::Error::DockerError => err
          warn "Problem with #{operation} -> #{name}: #{err}"
        end
        sleep 2
        forget
      end
      Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{max_retries} attempts. Dying."
    end

    def up(*args)    invoke_until_satisfied(:up,    *args) ; end
    def ready(*args) invoke_until_satisfied(:ready, *args) ; end
    def down(*args)  invoke_until_satisfied(:down,  *args) ; end
    def clear(*args) invoke_until_satisfied(:clear, *args) ; end

    def _up
      case state
      when :running then              return true
      when :paused  then _unpause ;   return false # wait for unpause
      when :stopped then _start   ;   return false # wait for start
      when :restart then              return false
      when :absent  then ready    ;   return false # wait for ready
      else return false # don't know, hope we figure it out.
      end
    end

    def _ready
      case state
      when :running then              return true
      when :paused  then              return true
      when :stopped then              return true
      when :restart then              return false # wait for restart
      when :absent  then _create  ;   return false # wait for create
      else return false # don't know, hope we figure it out.
      end
    end

    def _down
      case state
      when :running then _stop   ;    return false # wait for stop
      when :paused  then _stop   ;    return false # wait for stop
      when :stopped then              return true
      when :restart then              return false # wait for restart
      when :absent  then              return true
      else return false # don't know, hope we figure it out.
      end
    end

    def _clear
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
      Rucker.progress("  Creating #{desc}")
      self.docker_obj = Docker::Container.create_from_manifest(self)
      forget() ; self
    end

    # Start a created container
    def _start
      Rucker.progress("  Starting #{desc}")
      docker_obj.start_from_manifest(self)
      forget() ; self
    end

    # Stop a running container by sending `SIGTERM` and then `SIGKILL` after a grace period
    def _stop
      Rucker.progress("  Stopping #{desc}")
      docker_obj.stop_from_manifest(self)
      forget() ; self
    end

    # Remove a container completely.
    def _remove
      Rucker.progress("  Removing #{desc}")
      docker_obj.remove('v' => 'true')
      forget() ; self
    end

    # Pause all processes within a container. The docker pause command uses the cgroups freezer to suspend all processes in a container. Traditionally when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended. With the cgroups freezer the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
    def _pause()
      Rucker.progress("  Pausing #{desc}")
      docker_obj.pause()
      forget() ; self
    end
    # The docker unpause command uses the cgroups freezer to un-suspend all processes in a container.
    def _unpause()
      Rucker.progress("  Unpausing #{desc}")
      docker_obj.pause()
      forget() ; self
    end

    # Display the running processes of a container. Options are passed along to PS.
    def top(opts={})
      Rucker.progress("  Showing #{desc}'s top processes")
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

  class DataContainer < Container
    # def _up
    #   return true if exit_code == 0 # all that matters is that it was started once
    #   super
    # end
  end

  class ContainerCollection < Rucker::KeyedCollection
    include Rucker::Common
    class_attribute :max_retries; self.max_retries = 10

    def desc
      str = (item_type.try(:type_name) || 'Item')+'s'
      str << ' in ' << belongs_to.desc if belongs_to.respond_to?(:desc)
      str
    end

    def invoke_until_satisfied(operation, *args)
      max_retries.times do |idx|
        Rucker.progress("#{operation} -> #{length} #{item_type.type_name}#{idx > 1 ? " (#{idx})" : ''}")
        Rucker.progress("  #{desc} are #{state_desc}")
        successes = items.map do |ctr|
          begin
            ctr.public_send(:"_#{operation}", *args)
          rescue Docker::Error::DockerError => err
            warn "Problem with #{operation} -> #{ctr.name}: #{err}"
            sleep 1
          end
        end
        return true if successes.all? # we caused no changes in the world, so don't need to refresh
        sleep 1.5
        refresh!
      end
      Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{max_retries} attempts. Dying."
    end

    def up(*args)    invoke_until_satisfied(:up,    *args) ; end
    def ready(*args) invoke_until_satisfied(:ready, *args) ; end
    def down(*args)  invoke_until_satisfied(:down,  *args) ; end
    def clear(*args) invoke_until_satisfied(:clear, *args) ; end

    #
    # State managemet
    #

    def state
      map(&:state).uniq.compact
    end
    def running?() state == [:running] ; end
    def paused?()  state == [:paused]  ; end
    def stopped?() state == [:stopped] ; end
    def restart?() state == [:restart] ; end
    def absent?()  state == [:absent]  ; end
    def consistent?() state.length == 1 ; end

    def refresh!
      # Reset all the containers and get a lookup table of containers
      each{|ctr| ctr.forget ; ctr.remove_instance_variable(:@docker_obj) if ctr.instance_variable_defined?(:@docker_obj) }
      #
      # Grab all the containers
      #
      ctr_names = keys.to_set
      Docker::Container.all('all' => 'True').map do |docker_obj|
        # if any name matches a manifest, gift it; skip the docker_obj otherwised
        name = ctr_names.intersection(docker_obj.names).first or next
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

    # @return Rucker::Cluster the named cluster, or nil
    def cluster(name)    clusters[name] ; end

    # @return Rucker::Container the named container, or nil
    def container(name)  clusters.map{|cl| cl.container(name) }.compact.first ; end

    # Loads the chosen world from the layout yaml file
    # @return Rucker::World
    def self.load(layout_file, name)
      layout = YAML.load_file layout_file
      world_layout = layout[name.to_s]
      world_layout['clusters'] = world_layout['clusters'].map{|cl_name, ctrs| { name: cl_name, containers: ctrs } }
      world_layout['name'] = name
      receive(world_layout).refresh!
    end

    def refresh!
      containers.refresh!
      self
    end

    def up(*args)    clusters.each{|cl| cl.up(*args) } ; end
    def ready(*args) clusters.each{|cl| cl.ready(*args) } ; end
    def down(*args)  clusters.items.reverse.each{|cl| cl.down(*args) } ; end
    def clear(*args) clusters.items.reverse.each{|cl| cl.clear(*args) } ; end

    def clusters_slice(cl_names)
      return clusters if cl_names.to_s == 'all'
      Array.wrap(cl_names).map do |cl_name|
        cluster(cl_name) or abort("Can't find cluster #{cl_name} in #{self.inspect}")
      end
    end

    def containers
      return @containers if instance_variable_defined?(:@containers)
      @containers = Rucker::ContainerCollection.new(belongs_to: self, item_type: Rucker::Container)
      clusters.each do |cl|
        cl.containers.each{|cnt| @containers.add(cnt) }
      end
      @containers
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
