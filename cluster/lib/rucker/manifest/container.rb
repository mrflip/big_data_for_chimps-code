module Rucker
  module Manifest
    class Container < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
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
      field :doc,          :string, doc: "Description of this container's purpose"
      #
      collection :ports,   Rucker::Manifest::PortBindingCollection
      #
      accessor_field :actual, Rucker::Actual::ActualContainer, writer: :public, reader: :public
      accessor_field :image,  Rucker::Manifest::Image,         writer: :public
      accessor_field :world,  Rucker::Manifest::Base,          writer: :public
      #
      class_attribute :max_retries; self.max_retries = 10

      def id
        actual.try(:id)
      end

      def state
        return :absent if self.actual.blank?
        actual.state
      end

      def exit_code
        return -999 if self.actual.blank?
        actual.exit_code
      end

      def image_id()        image.try(:short_id)     ; end
      def image_repo_tag()  image.try(:repo_tag)     ; end

      def ip_address()      actual.try(:ip_address)  ; end

      def created_at()      actual.try(:created_at) ; end

      def started_at()      actual.try(:started_at) ; end

      def stopped_at()      actual.try(:stopped_at) ; end

      def published_ports()
        ports.items.select(&:published?)
      end

      def linked_containers
        named_ctrs = links.map do |link_str|
          ctr_name, as_name = link_str.split(':', 2)
          ctr = Rucker.world.container(ctr_name)
          ctr.present? or raise("Missing linked container for #{ctr_name}:#{as_name} in #{self}: #{self.links}")
          #
          [as_name, ctr]
        end
        Hash[named_ctrs]
      end

      #
      # Orchestration movements
      #

      def up?()     running?                        ; end
      def ready?()  running? || stopped? || paused? ; end
      def down?()   absent?  || stopped?            ; end
      def clear?()  absent?                         ; end

      # Take the next step towards the up goal
      def _up
        _ready_linked or return false # wait for dependent containers
        _up_linked    or return false # wait for dependent containers
        case state
        when :running then            return true
        when :paused  then _unpause ; return false # wait for unpause
        when :stopped then _start   ; return false # wait for start
        when :restart then            return false
        when :absent  then _ready   ; return false # wait for ready
        else                          return false # don't know, hope we figure it out.
        end
      end

      def _ready_image
        return true if image.try(:ready?)  # if no image, pull it
        image.try(:_ready)
      end

      def _up_linked
        linked_containers.each do |_, other|
          next if other.up?
          other._up
          return false
        end
        true
      end

      def _ready_linked
        linked_containers.each do |oname, other|
          next if other.ready?
          other._ready
          return false
        end
        true
      end

      # def _ready_linked(results)
      #   linked_containers.each do |oname, other|
      #     if other.blank?
      #       results[:fail] << [:]
      #     end
      #     #
      #     next if other.ready?
      #     other._ready
      #     return false
      #   end
      #   true
      # end

      # Take the next step towards the ready goal
      def _ready
        _ready_image  or return false # wait for pull
        case state
        when :running then            return true
        when :paused  then            return true
        when :stopped then            return true
        when :restart then            return false # wait for restart
        when :absent  then _create  ; return false # wait for create
        else                          return false # don't know, hope we figure it out.
        end
      end

      # Take the next step towards the down goal
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

      # Take the next step towards the clear goal
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
        Rucker.progress(:creating, self)
        self.actual = Rucker::Actual::ActualContainer.create_from_manifest(self)
        forget() ; self
      end

      # Start a created container
      def _start
        Rucker.progress(:starting, self)
        actual.start_from_manifest(self)
        forget() ; self
      end

      # Stop a running container by sending `SIGTERM` and then `SIGKILL` after a grace period
      def _stop
        Rucker.progress(:stopping, self)
        actual.stop_from_manifest(self)
        forget() ; self
      end

      # Remove a container completely.
      def _remove
        Rucker.progress(:removing, self)
        actual.remove('v' => 'true')
        forget() ; self
      end

      # Pause all processes within a container. The docker pause command uses the cgroups freezer to suspend all processes in a container. Traditionally when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended. With the cgroups freezer the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
      def _pause()
        Rucker.progress(:pausing, self)
        actual.pause()
        forget() ; self
      end

      # The docker unpause command uses the cgroups freezer to un-suspend all processes in a container.
      def _unpause()
        Rucker.progress(:unpausing, self)
        actual.pause()
        forget() ; self
      end

      def commit(new_name)
        Rucker.progress(:creating, "image #{new_name}", from: ['current state of', :cya, self.desc])
        img = actual.commit(new_name)
        Rucker.progress(:created,  img, now: "has names #{img.names.join(',')} and id #{img.short_id}")
        world.refresh!
        self
      end

      # Display the running processes of a container. Options are passed along to PS.
      def top(opts={})
        Rucker.progress(:listing_processes_on, self)
        Rucker.output( actual.top(opts) )
      end

      def logs(opts={})
        Rucker.progress(:showing_logs_for, self)
        opts = opts.reverse_merge(stdout: true, stderr: true, tail: 1000, timestamps: true)
        Rucker.output( actual.logs(opts) )
      end

      def forget
        actual.forget if actual.present?
        self
      end

      def to_wire(*)
        super.merge(:_actual => actual.try(:to_wire))
      end
    end

    class DataContainer < Rucker::Manifest::Container
      def _up
        # If it was started once, that's enough.
        return true if (started_at) && (exit_code == 0)
        super
      end
    end

    class ContainerCollection < Rucker::KeyedCollection
      include Rucker::Manifest::HasState
      #
      self.item_type = Rucker::Manifest::Container
      class_attribute :max_retries; self.max_retries = 6

      def desc
        str = (item_type.try(:type_name) || 'Item')+'s'
        str << ' in ' << belongs_to.desc if belongs_to.respond_to?(:desc)
        str
      end

      def up(*args)    invoke_until_satisfied(:up,    *args) ; end
      def ready(*args) invoke_until_satisfied(:ready, *args) ; end
      def down(*args)  invoke_until_satisfied(:down,  *args) ; end
      def clear(*args) invoke_until_satisfied(:clear, *args) ; end

      def state
        map(&:state).uniq.compact
      end

      def up?()    items.all?(&:up?)    ; end
      def ready?() items.all?(&:ready?) ; end
      def down?()  items.all?(&:down?)  ; end
      def clear?() items.all?(&:clear?) ; end

      def invoke_until_satisfied(operation, *args)
        max_retries.times do |idx|
          Rucker.progress(:"get_#{operation}", self, pass: idx, from: state_desc, for: keys.join(','), indent: 0)
          successes = items.map do |ctr|
            begin
              ctr.public_send(:"_#{operation}", *args)
            rescue Docker::Error::DockerError => err
              Rucker.warn "Problem with #{operation} -> #{ctr.name}: #{err}"
              sleep 1
            end
          end
          return true if successes.all? # we caused no changes in the world, so don't need to refresh
          sleep 1.5
          refresh!
        end
        Rucker.die "Could not bring #{self.inspect_compact} to #{operation} after #{max_retries} attempts. Dying."
      end

      def logs()
        each do |ctr|
          Rucker.output Rucker.banner("Logs for ", :bgr, ctr.desc)
          ctr.logs
        end
      end

      def refresh!
        # Reset all the containers and get a lookup table of containers
        each{|ctr| ctr.forget ; ctr.remove_instance_variable(:@actual) if ctr.instance_variable_defined?(:@actual) }
        #
        # Grab all the containers
        #
        ctr_names = keys.to_set
        Rucker::Actual::ActualContainer.all('all' => 'True').map do |actual|
          # if any name matches a manifest, gift it; skip the actual otherwised
          name = ctr_names.intersection(actual.names).first or next
          self[name].actual = actual
        end
        self
      end
      #
    end
  end
end
