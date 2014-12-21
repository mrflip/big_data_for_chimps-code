module Rucker
  module Manifest
    class Container < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      include Rucker::HasGoals
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
      accessor_field :actual, Rucker::Actual::DockerContainer, writer: :public, reader: :public
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

      def volume_containers
        named_ctrs = Hash[
          volumes_from.map{|nm| [nm, Rucker.world.container(nm)] }]
      end

      #
      # Orchestration movements
      #

      before :up do
        [ [image, :up] ] +
          linked_containers.values.map{|ctr| [ctr, :up] } +
          volume_containers.values.map{|ctr| [ctr, :up] } +
          [ [self, :ready] ]
      end

      goal :up do
        case state
        when :paused       then unpause! ; return :unpause!
        when :stopped      then start!   ; return :start!
        when :init         then start!   ; return :start!
        when :starting, :restart, :scaling, :redeploying, :stopping, :partly
          return :wait
        else
          # :not_running, :absent fall to here
          return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      before :ready do
        [ [image, :up] ] +
          linked_containers.values.map{|ctr| [ctr, :ready] } +
          volume_containers.values.map{|ctr| [ctr, :ready] }
      end

      goal :ready do
        case state
        when :absent       then create!  ; return :create!
        when :starting, :restart, :scaling, :redeploying, :stopping, :partly
          return :wait
        when :not_running
          warn "Not running state -- must remove and then ready"
          remove!
          return :acted
        else
          return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      # Take the next step towards the down goal
      goal :down do
        case state
        when :running      then stop!   ;  return :stop!
        when :paused       then stop!   ;  return :stop!
        when :partly       then stop!   ;  return :stop!
        when :starting, :restart, :scaling, :redeploying, :stopping
          return :wait
        else
          return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      before :clear do
        [ [self, :down] ]
      end

      # Take the next step towards the clear goal
      goal :clear do
        case state
        when :not_running  then remove!      ; return :remove!
        when :stopped      then remove!      ; return :remove!
        when :init         then remove!      ; return :remove!
        when :starting, :restart, :scaling, :redeploying, :stopping
          return :wait
        else
          # includes :running, :paused, :partly
          return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      READY_STATES = [
        :running, :paused, :stopped, :init, :starting,
        :restart, :scaling, :redeploying, :stopping
      ].to_set
      DOWN_STATES  = [
        :stopped, :init, :not_running, :absent
      ]

      def up?()     running?                        ; end
      def ready?()  READY_STATES.include?(state)    ; end
      def down?()   DOWN_STATES.include?(state)     ; end
      def clear?()  absent?                         ; end

      #
      # Procedural actions
      #

      protected

      # Creates a container rfomr the specified image and prepares it for
      # running the specified command. You can then start it at any point.
      def create!
        Rucker.progress(:creating, self)
        self.actual = Rucker.provider.create_using_manifest(self)
        forget()
      end

      # Start a created container
      def start!
        Rucker.progress(:starting, self)
        actual.start_using_manifest(self)
        forget()
      end

      # Stop a running container by sending `SIGTERM` and then `SIGKILL` after a grace period
      def stop!
        Rucker.progress(:stopping, self)
        actual.stop_using_manifest(self)
        forget()
      end

      # Remove a container completely.
      def remove!
        Rucker.progress(:removing, self)
        actual.remove_using_manifest('v' => 'true')
        forget()
      end

      # Pause all processes within a container. The docker pause command uses the cgroups freezer to suspend all processes in a container. Traditionally when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended. With the cgroups freezer the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
      def pause!
        Rucker.progress(:pausing, self)
        actual.pause()
        forget()
      end

      # The docker unpause command uses the cgroups freezer to un-suspend all processes in a container.
      def unpause!
        Rucker.progress(:unpausing, self)
        actual.pause()
        forget()
      end

      public

      # def commit!(new_name)
      #   Rucker.progress(:creating, "image #{new_name}", from: ['current state of', :cya, self.desc])
      #   img = actual.commit(new_name)
      #   Rucker.progress(:created,  img, now: "has names #{img.names.join(',')} and id #{img.short_id}")
      #   world.refresh!
      # end

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
      end

      def to_wire(*)
        super.merge(:_actual => actual.try(:to_wire))
      end
    end

    class DataContainer < Rucker::Manifest::Container
      def up?
        # If it was started once, that's enough.
        ((started_at) && (exit_code == 0)) || super
      end
      def _up
        return true if up?
        super
      end
    end

    class ContainerCollection < Rucker::KeyedCollection
      include Rucker::Manifest::HasState
      #
      self.item_type = Rucker::Manifest::Container
      class_attribute :max_retries; self.max_retries = 12

      def desc
        str = (item_type.try(:type_name) || 'Item')+'s'
        str << ' in ' << belongs_to.desc if belongs_to.respond_to?(:desc)
        str
      end

      def state
        map(&:state).uniq.compact
      end

      def up(*args)    Rucker::Manifest::Container.reach(self.items, :up)    ; end
      def ready(*args) Rucker::Manifest::Container.reach(self.items, :ready) ; end
      def down(*args)  Rucker::Manifest::Container.reach(self.items, :down)  ; end
      def clear(*args) Rucker::Manifest::Container.reach(self.items, :clear) ; end

      def up?()    items.all?(&:up?)    ; end
      def ready?() items.all?(&:ready?) ; end
      def down?()  items.all?(&:down?)  ; end
      def clear?() items.all?(&:clear?) ; end

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
        Rucker.provider.all().map do |actual|
          next unless actual.exists?
          # p [actual, actual.names, ctr_names ]
          # if any name matches a manifest, gift it; skip the actual otherwised
          ctr_names.intersection(actual.names).each do |name|
            self[name].actual = actual
          end
        end
        self
      end
      #
    end
  end
end
