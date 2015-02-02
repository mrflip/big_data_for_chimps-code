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
      field :container_names, :array, of: :symbol
      #
      accessor_field :containers, Rucker::Manifest::ContainerCollection
      accessor_field :actual,     ::Tutum::NodeCluster, reader: :public, writer: :public
      accessor_field :node,       ::Tutum::Node,        reader: :public, writer: :public

      # ===========================================================================
      #
      # Delegated Properties
      #

      # ===========================================================================
      #
      # States
      #

      def state()
        actual_or(:state, :absent)
      end

      def transition?() actual_or(:transition?, false) ; end
      def absent?()     actual_or(:absent?, true)      ; end
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
        [ [self, :ready] ]
      end

      goal :up do
        start!
        return :start!
      end

      goal :ready do
        create!
        return :create!
      end

      goal :down do
        stop!
        return :stop!
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

      def create!()
        Rucker.progress(:creating, self)
        self.actual = Rucker.node_provider.create_using_manifest(self)
        forget
      end

      def start!()
        Rucker.progress(:starting, self)
        actual.start_using_manifest(self)
        forget
      end

      def stop!()
        Rucker.progress(:stopping, self)
        actual.stop_using_manifest(self)
        forget
      end

      def remove!()
        Rucker.progress(:removing, self)
        actual.remove_using_manifest(self)
        forget
      end

      # ===========================================================================
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
          self.receive_container_names(arr)
        else
          super
        end
      end

    end

    #
    #
    #
    class NodeCollection < Rucker::KeyedCollection
      include Rucker::Manifest::HasState
      include Rucker::CollectsGoals
      #
      self.item_type = Rucker::Manifest::Node

      def refresh!
        # Reset all the images
        each{|img| img.forget ; img.unset_actual }
        Rucker.node_provider.actualize_manifests(self)
        self
      end

    end

  end
end
