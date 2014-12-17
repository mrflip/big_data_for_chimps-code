module Rucker
  module Manifest
    class Node < Rucker::Manifest::Base
      include Rucker::Manifest::HasState
      #
      field :name,      :symbol
      field :node_type, :string
      field :region,    :string
      field :instances, :integer
      field :container_names, :string
      accessor_field :containers, Rucker::Manifest::ContainerCollection
      accessor_field :actual,     ::Tutum::NodeCluster, reader: :public, writer: :public
      accessor_field :node,       ::Tutum::Node,        reader: :public, writer: :public

      def _create()
        tags_list = (container_names + ["region--#{region}"]).
          map{|tag| {name: tag} }
        self.actual = ::Tutum::NodeCluster.create(
          name: name,
          node_type: "/api/v1/nodetype/aws/#{node_type}/",
          region:    "/api/v1/region/aws/#{region}/",
          target_num_nodes: instances,
          tags: tags_list )
        forget
      end

      def _start()
        if actual.deployable?
          actual.deploy
        else
          actual.update(target_num_nodes: instances)
        end
        forget
      end

      def _stop()
        actual.update(target_num_nodes: 0)
        forget
      end

      def _remove
        actual.terminate
        forget
      end

      def state()
        return :absent if self.actual.blank?
        actual.state
      end

      def receive_containers(arr)
        if arr.all?{|val| val.is_a?(String) }
          self.container_names = arr
        else
          super
        end
      end

      def up?()         actual.try(:deployed?) || false  ; end
      def ready?()      actual.try(:ready?)     || false ; end
      def down?()       actual.nil? || actual.down?      ; end
      def absent?()     actual.nil? || actual.absent?    ; end

      def forget()
      end
      def refresh!()
        self.forget
        actual.refresh!
      end

    end

    class NodeCollection < Rucker::KeyedCollection
      self.item_type = Rucker::Manifest::Node

      def refresh!
        Rucker.tutum
        # Reset all the images
        each{|img| img.forget ; img.unset_actual }
        # Gift the actual image to each manifest that refers to it.
        ::Tutum::NodeCluster.list().map do |act|
          next if act.absent?
          node_manifest = self[act.name] or next
          node_manifest.receive_actual(act)
        end
        self
      end

    end

  end
end
