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

      # ===========================================================================
      #
      # Delegated Properties
      #

      def id
        actual.try(:id)
      end

      def dashed_name
        name.to_s.gsub(/_/, '-').to_sym
      end

      def exit_code
        actual_or(:exit_code, -999)
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

      # ===========================================================================
      #
      # States
      #

      def state
        actual_or(:state, :absent)
      end

      def running?()    state == :running              ; end
      def paused?()     state == :paused               ; end
      def stopped?()    state == :stopped              ; end
      def init?()       state == :init                 ; end
      def partly?()     state == :partly               ; end

      def transition?() actual_or(:transition?, false) ; end
      def absent?()     actual_or(:absent?,     true)  ; end
      def exists?()     not absent?                    ; end

      def up?()         actual_or(:up?,     false)     ; end
      def ready?()      actual_or(:ready?,  false)     ; end
      def down?()       actual_or(:down?,   true)      ; end
      def clear?()      actual_or(:clear?,  true)      ; end

      # ===========================================================================
      #
      # Goals
      #

      before :up do
        [ [image, :up] ] +
          linked_containers.values.map{|ctr| [ctr, :up] } +
          volume_containers.values.map{|ctr| [ctr, :up] } +
          [ [self, :ready] ]
      end

      goal :up do
        case
        when paused?     then unpause! ; return :unpause!
        when stopped?    then start!   ; return :start!
        when init?       then start!   ; return :start!
        when partly?     then start!   ; return :start!
        else return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      before :ready do
        [ [image, :up] ] +
          linked_containers.values.map{|ctr| [ctr, :ready] } +
          volume_containers.values.map{|ctr| [ctr, :ready] }
      end

      goal :ready do
        case
        when absent?     then create!  ; return :create!
        when :not_running
          warn "Not running state -- must remove and then ready"
          remove! ; return :remove!
        else return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      # Take the next step towards the down goal
      goal :down do
        case
        when running?    then stop!   ;  return :stop!
        when paused?     then stop!   ;  return :stop!
        when partly?     then stop!   ;  return :stop!
        else return RuntimeError.new("Should not see state #{state} for #{self}")
        end
      end

      before :clear do
        [ [self, :down] ]
      end

      goal :clear do
        remove!
        return :remove!
      end

      # ===========================================================================
      #
      # Actions
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
        actual.remove_using_manifest(self)
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


      # ===========================================================================
      #
      # Mechanics
      #

      def forget
        actual.forget if actual.present?
      end

      def to_wire(*)
        super.merge(:_actual => actual.try(:to_wire))
      end
    end

    #
    # Data containers don't need to be running.
    #
    class DataContainer < Rucker::Manifest::Container
      def up?
        # If it was started once, that's enough.
        ((stopped_at) && (exit_code == 0)) || super
      end
    end

    #
    # Collection of containers
    #
    class ContainerCollection < Rucker::KeyedCollection
      include Rucker::Manifest::HasState
      include Rucker::CollectsGoals
      #
      self.item_type = Rucker::Manifest::Container
      class_attribute :max_retries; self.max_retries = 12

      def desc
        str = (item_type.try(:type_name) || 'Item')+'s'
        str << ' in ' << belongs_to.desc if belongs_to.respond_to?(:desc)
        str
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
        Rucker.provider.all().map do |actual|
          Rucker.progress(:matching, actual.to_s, names: ctr_names.to_a.inspect)
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
