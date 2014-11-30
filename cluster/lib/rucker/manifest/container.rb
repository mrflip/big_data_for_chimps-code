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
      accessor_field :actual, Rucker::Actual::ActualContainer, writer: true
      protected :actual
      accessor_field :image,  Rucker::Manifest::Image, writer: true
      protected :image
      #
      class_attribute :max_retries; self.max_retries = 10

      def state
        return :absent if self.actual.blank?
        actual.state
      end

      def exit_code
        return -999 if self.actual.blank?
        actual.exit_code
      end

      def image_id()        image.try(:short_id)     ; end

      def ip_address()      actual.try(:ip_address)  ; end

      def created_at()      actual.try(:created_at) ; end

      def started_at()      actual.try(:started_at) ; end

      def stopped_at()      actual.try(:stopped_at) ; end

      def published_ports()
        ports.items.select(&:published?)
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
        case state
        when :running then            return true
        when :paused  then _unpause ; return false # wait for unpause
        when :stopped then _start   ; return false # wait for start
        when :restart then            return false
        when :absent  then _ready   ; return false # wait for ready
        else                          return false # don't know, hope we figure it out.
        end
      end

      # Take the next step towards the ready goal
      def _ready
        return image.try(:ready) unless image.try(:ready?)  # if no image, pull it
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
        return true if exit_code == 0 # all that matters is that it was started once
        super
      end
    end

    class ContainerCollection < Rucker::KeyedCollection
      include Rucker::Manifest::HasState
      #
      self.item_type = Rucker::Manifest::Container
      class_attribute :max_retries; self.max_retries = 10

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
          Rucker.output("#{operation} -> #{belongs_to.desc} (#{length} #{item_type.type_name})#{idx > 1 ? " (#{idx})" : ''}")
          Rucker.output("  #{desc} are #{state_desc}")
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
