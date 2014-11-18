module Rucker
  module Actual

    class Container < Rucker::Actual::Base
      field :name,         :string,  doc: "Container name, without initial slash"
      field :id,           :string,  doc: "Hexadecimal unique id"
      field :docker_obj,   Whatever, doc: "Docker API object used to prepare"
      field :manifest,     Rucker::Container, doc: "Configuration manifest that prescribed this instance's behavior"
      #
      field :created_at,   :time,   doc: "Time the object was created"
      field :stopped_at,   :time,   doc: "Time the object last stopped. This may be present even if the container is running"
      field :started_at,   :time,   doc: "Time the object last started. This may be present even if the container is running"
      #
      field :status_str,   :string, doc: "A readable description of the object's state"
      field :state,        :symbol, doc: "One of :running, :paused, :restart, :stopped, :absent"
      field :ip_address,   :string
      #
      field :image_id,     :string
      field :image_name,   :string
      #
      field :other_names,  :array, of: String, default: ->{ [] }
      field :links,        :array, default: ->{ [] }
      field :volumes_from, :array, default: ->{ [] }
      #
      field :volumes,      :array, default: ->{ [] }
      #
      field :hostname,     :string
      field :ports,        :array, default: ->{ [] }
      field :exposes,      :array, default: ->{ [] }
      #
      # field :entrypoint,   :string
      field :command,      :string
      field :envs,         :array, default: ->{ [] }
      field :entry_args,   :array, default: ->{ [] }

      def ready
        case state
        when :running then              return true
        when :paused  then              return true
        when :stopped then              return true
        when :restart then              return false # wait for restart
        when :absent  then _create  ;   return false # wait for create
        end
      end

      def up
        case state
        when :running then              return true
        when :paused  then _unpause ;   return false # wait for unpause
        when :stopped then _start   ;   return false # wait for start
        when :restart then              return false
        when :absent  then ready    ;   return false # wait for ready
        end
      end

      def down
        case state
        when :running then _stop   ;    return false # wait for stop
        when :paused  then _stop   ;    return false # wait for stop
        when :stopped then              return true
        when :restart then              return false # wait for restart
        when :absent  then              return true
        end
      end

      def delete
        case state
        when :running then down ;       return false # wait for down
        when :paused  then down ;       return false # wait for down
        when :stopped then _remove    ; return false # wait for remove
        when :restart then              return false
        when :absent  then            ; return true
        end
      end

      # Creates a container rfomr the specified image and prepares it for
      # running the specified command. You can then start it at any point.
      def _create
        hsh = manifest.raw_creation_hsh
        self.docker_obj = Docker::Container.create(hsh)
      end

      # Start a created container
      def _start
        hsh = manifest.raw_start_hsh.merge({ 'Id' : id })
        docker_obj.start(hsh).forget()
      end

      # Stop a running container by sending `SIGTERM` and then `SIGKILL` after a grace period
      def _stop
        docker_obj.stop().forget()
      end

      # Remove a container completely.
      def _remove
        docker_obj.remove('v' => 'true').forget()
      end

      # Pause all processes within a container. The docker pause command uses the cgroups freezer to suspend all processes in a container. Traditionally when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended. With the cgroups freezer the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
      def _pause()
        docker_obj.pause().forget()
      end
      # The docker unpause command uses the cgroups freezer to un-suspend all processes in a container.
      def _unpause()
        docker_obj.pause().forget()
      end

      # Display the running processes of a container. Options are passed along to PS.
      def top(opts={})
        docker_obj.top(opts)
      end
    end

    class Image < Rucker::Actual::Base
      include Rucker::Common::Image
      #
      field :name,        :string,  doc: "Full name -- ns/slug:tag -- for image"
      field :id,          :string,  doc: "Hexadecimal unique id"
      field :docker_obj,  Whatever
      field :manifest,    Rucker::Image
      #
      field :created_at,  :time,    doc: "Human-readable time since creation"
      #
      field :size,        :integer, doc: "Virtual size, in bytes (the size of all layers in an image)"
      field :ago,         :string,  doc: "Human-readable time since creation"
      field :cmd,         :string,  doc: "If known, the most recent command used to build this image"
      #
      # field :parent_layer, :string, doc: "Image ID of the image layer this was created from"
      # field :layer_size, :integer, doc: "Incremental size of this image above its parent_layer"
      # field :container, :string, doc: "Container ID of the container created from"
      # field :confainer_config: :hash, { Hostname User Memory MemorySwap AttachStdin AttachStdout AttachStderr PortSpecs Tty OpenStdin StdinOnce Env Cmd Dns Image Volumes VolumesFrom WorkingDir }

      # @return A shortened version of the command string, limited to 100 characters
      def short_cmd()   cmd.to_s[0..100] ; end

      # @return Magnitude of human-readable size
      def sz_mag()      Rucker.bytes_to_magnitude(size) ; end

      # Units (B, kB, MB, GB) of human-readable size
      def sz_units()    Rucker.bytes_to_units(size) ; end

      # def self.dump_images(img_names)
      #   # actual_world = Rucker::Actual::World.new(WORLD)
      #   # actual_world.refresh
      #   # actual_world.images
      #   # # puts Rucker::Actual::Image.images_table(actual_world.images).join("\n")
      # end
    end

    class World < Rucker::Actual::Base
      field :manifest, Rucker::World
      collection :containers, Rucker::KeyedCollection, item_type: Rucker::Actual::Container
      collection :images,     Rucker::KeyedCollection, item_type: Rucker::Actual::Image
      #
    end

    class Universe < Rucker::Actual::Base
      field :num_containers, :integer, doc: "Total number of created containers in any state"
      field :num_images,     :integer
      # field :driver, :string
      # execution_driver
      # kernel_version
      # debug_mode Debug
      # num_file_descriptors
      # num_goroutines
      # num_listeners
      # init_path
      # index_server_address
      # memory_limit
      # swap_limit
      # ipv4_forwarding
    end
  end
end
