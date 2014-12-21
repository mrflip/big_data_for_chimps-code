module Rucker
  module Manifest
    class Node < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      include Rucker::HasGoals
      #
      field :name,      :symbol
      field :node_type, :string
      field :region,    :string
      field :instances, :integer
      field :container_names, :string
      accessor_field :containers, Rucker::Manifest::ContainerCollection
      accessor_field :actual,     ::Tutum::NodeCluster, reader: :public, writer: :public
      accessor_field :node,       ::Tutum::Node,        reader: :public, writer: :public

      def create!()
        self.actual = Rucker.node_provider.create_using_manifest(self)
        forget
      end

      def start!()
        actual.start_using_manifest(self)
        forget
      end

      def stop!()
        actual.stop_using_manifest(self)
        forget
      end

      def remove!()
        actual.remove_using_manifest(self)
        forget
      end

      def state()
        return :absent if self.actual.nil?
        actual.state
      end

      #
      # Orchestration movements
      #

      def actual_or(meth, val)
        actual.nil? ? val : actual.public_send(meth)
      end

      def up?()         actual_or(:up?,     false)     ; end
      def ready?()      actual_or(:ready?,  false)     ; end
      def down?()       actual_or(:down?,   true)      ; end
      def absent?()     actual_or(:absent?, true)      ; end
      def clear?()      actual_or(:clear?,  true)      ; end
      def transition?() actual_or(:transition?, false) ; end

      before :up do
        [ [self, :ready] ]
      end

      goal :up do
        case
        when transition? then           return :wait
        when ready?      then start! ;  return :start!
        else
          return RuntimeError.new("Should not advance to :up from state #{state} -- #{self}")
        end
      end

      goal :ready do
        case
        when transition? then           return :wait
        when absent?     then create! ; return :create!
        else
          return RuntimeError.new("Should not advance to :ready from state #{state} -- #{self}")
        end
      end

      # Take the next step towards the down goal
      goal :down do
        case
        when transition? then           return :wait
        when up?         then stop! ;   return :stop!
        else
          return RuntimeError.new("Should not advance to :clear from state #{state} -- #{self}")
        end
      end

      # Take the next step towards the clear goal
      goal :clear do
        case
        when transition? then           return :wait
        else
          return :remove!
        end
      end

      #
      # Mechanics
      #

      def forget()
        actual.try(:forget)
      end

      def refresh!()
        self.forget
        actual.try(:refresh!)
      end

      def receive_containers(arr)
        if arr.all?{|val| val.is_a?(String) }
          self.container_names = arr
        else
          super
        end
      end

    end

    class NodeCollection < Rucker::KeyedCollection
      self.item_type = Rucker::Manifest::Node

      def refresh!
        # Reset all the images
        each{|img| img.forget ; img.unset_actual }
        Rucker.node_provider.actualize_manifests(self)
        self
      end

      def up(*args)    Rucker::Manifest::Node.reach(self.items, :up)    ; end
      def ready(*args) Rucker::Manifest::Node.reach(self.items, :ready) ; end
      def down(*args)  Rucker::Manifest::Node.reach(self.items, :down)  ; end
      def clear(*args) Rucker::Manifest::Node.reach(self.items, :clear) ; end

      def up?()    items.all?(&:up?)    ; end
      def ready?() items.all?(&:ready?) ; end
      def down?()  items.all?(&:down?)  ; end
      def clear?() items.all?(&:clear?) ; end

    end

  end
end
