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
    accessor_field :docker_obj, Docker::Container
    accessor_field :image,      Rucker::Image
    #
    class_attribute :max_retries; self.max_retries = 10

    def receive_image_name(val)
      img_name = Rucker::Image.normalize_name(super(val))
      write_attribute(:image_name, img_name)
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
          Rucker.progress("#{operation} -> single #{desc} (#{state_desc}) #{idx > 1 ? " (#{idx})" : ''}")
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

    def up?()     running?                        ; end
    def ready?()  running? || stopped? || paused? ; end
    def down?()   absent?  || stopped?            ; end
    def clear?()  absent?                         ; end
    #
    def running?() state == :running ; end
    def paused?()  state == :paused ; end
    def stopped?() state == :stopped ; end
    def restart?() state == :restart ; end
    def absent?()  state == :absent ; end

    def _up
      case state
      when :running then            return true
      when :paused  then _unpause ; return false # wait for unpause
      when :stopped then _start   ; return false # wait for start
      when :restart then            return false
      when :absent  then _ready   ; return false # wait for ready
      else                          return false # don't know, hope we figure it out.
      end
    end

    def _ready
      image.try(:ready) or return false  # if no image, pull it
      case state
      when :running then            return true
      when :paused  then            return true
      when :stopped then            return true
      when :restart then            return false # wait for restart
      when :absent  then _create  ; return false # wait for create
      else                          return false # don't know, hope we figure it out.
      end
    end

    def _down
      case state
      when :running then _stop    ; return false # wait for stop
      when :paused  then _stop    ; return false # wait for stop
      when :stopped then            return true
      when :restart then            return false # wait for restart
      when :absent  then            return true
      else                          return false # don't know, hope we figure it out.
      end
    end

    def _clear
      case state
      when :running then _down    ; return false # wait for down
      when :paused  then _down    ; return false # wait for down
      when :stopped then _remove  ; return false # wait for remove
      when :restart then            return false
      when :absent  then          ; return true
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
        Rucker.progress("#{operation} -> #{belongs_to.desc} (#{length} #{item_type.type_name})#{idx > 1 ? " (#{idx})" : ''}")
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
    accessor_field :world
    collection :containers, Rucker::ContainerCollection, item_type: Rucker::Container
    #
    def container(name)   containers[name.to_sym] ; end
    def container_names() containers.keys ; end

    def image_names()     containers.map(&:image_name).uniq ;  end

    def images()
      world.images_slice(image_names)
    end

    def up(*args)
      containers.up(*args)
    end
    def ready(*args)
      containers.ready(*args)
    end
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

    #
    # Machinery
    #

    def containers_slice(names='all', opts={})
      containers.slice(*names)
    end

    # def check_container_keys(ctr_names, opts={})
    #   ctr_names = Array.wrap(ctr_names).map(&:to_sym)
    #   return containers.keys if ctr_names.first == :all
    #   unless opts[:ignore_extra] || containers.all_present?(ctr_names) then warn("Keys #{containers.extra_keys(ctr_names)} aren't present in this cluster, skipping") ; end
    #   (ctr_names & containers.keys) # intersection
    # end


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
    field :layout_file, :string
    #
    collection :clusters,  ClusterCollection, item_type: Rucker::Cluster
    collection :images,    ImageCollection,   item_type: Rucker::Image

    # Loads the chosen world from the layout yaml file
    # @return Rucker::World
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
      images.refresh!
      containers.refresh!
      containers.each{|ctr| ctr.image = images[ctr.image_name] or warn "No image '#{ctr.image_name}' defined for container #{ctr}. Check #{layout_file}"}
      self
    end

    #
    # Actions
    #

    def up(*args)    clusters.each{|cl| cl.up(*args) } ; end
    def ready(*args) clusters.each{|cl| cl.ready(*args) } ; end
    def down(*args)  clusters.items.reverse.each{|cl| cl.down(*args) } ; end
    def clear(*args) clusters.items.reverse.each{|cl| cl.clear(*args) } ; end

    #
    # Slicing
    #

    # @return Rucker::Cluster the named cluster, or nil
    def cluster(name)    clusters[name] ; end

    # @return Rucker::Container the named container, or nil
    def container(name)  clusters.map{|cl| cl.container(name) }.compact.first ; end

    # @return Rucker::Image the named  image, or nil
    def image(name)      images[name] ; end

    # @return Rucker::ClusterCollection the named clusters
    def clusters_slice(cl_names)
      clusters.slice(*cl_names)
    end

    # @return Rucker::ImageCollection the named images
    def images_slice(img_names)
      images.slice(*img_names)
    end

    # @return Rucker::ContainerCollection the named containers
    def containers_slice(names)
      containers.slice(*names)
    end

    def containers
      return @containers if instance_variable_defined?(:@containers)
      @containers = Rucker::ContainerCollection.new(belongs_to: self, item_type: Rucker::Container)
      clusters.each do |cl|
        cl.containers.each{|cnt| @containers.add(cnt) }
      end
      @containers
    end

    # @return [Array[Symbol]] a sorted list of all states seen in the world.
    def state
      clusters.map{|cl| cl.state }.flatten.uniq.sort
    end

    # def refresh_images!
    #   receive_images(fetch_raw_images)
    # end
    #
    # def fetch_raw_images
    #   docker_objs = Docker::Image.all
    #   image_manifests = manifest.images
    #   docker_objs.map do |docker_obj|
    #     info = docker_obj.info
    #     info['RepoTags'].map do |tagged_name|
    #       next if tagged_name == '<none>:<none>' # all of ours are tagged
    #       image_manifest = image_manifests[tagged_name]
    #       next unless image_manifest.present?
    #       raw_image = {
    #         name:       tagged_name,
    #         id:         info['id'],
    #         created_at: info['Created'],
    #         size:       info['VirtualSize'],
    #         manifest:   image_manifest,
    #         docker_obj: docker_obj,
    #         # parent_id:  info['ParentId'],
    #         # layer_size: info['Size'],
    #       }
    #     end
    #   end.flatten.compact
    # end
  end

end
