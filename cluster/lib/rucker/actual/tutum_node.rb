module Rucker
  module Actual

    class TutumNode < ::Tutum::NodeCluster

      def self.create_using_manifest(mft)
        self.create(
          name:      mft.name,
          node_type: "/api/v1/nodetype/aws/#{mft.node_type}/",
          region:    "/api/v1/region/aws/#{mft.region}/",
          tags:      tutum_tags_list(mft),
          target_num_nodes: mft.instances,
          )
      end

      def start_using_manifest(mft)
        if deployable?
          deploy
        else
          update(target_num_nodes: mft.instances, tags: self.class.tutum_tags_list(mft))
        end
      end

      def stop_using_manifest(mft)
        update(target_num_nodes: 0, tags: self.class.tutum_tags_list(mft))
      end

      def remove_using_manifest(mft)
        terminate
      end

      def self.tutum_tags_list(mft)
        mft.container_names.map{|tag| {name: tag} }
      end

      def self.actualize_manifests(coll)
        Rucker.tutum
        # Gift the actual image to each manifest that refers to it.
        self.list().map do |act|
          next if act.absent?
          mft = coll[act.name.to_sym] or next
          mft.receive_actual(act)
        end
      end

    end
  end
end
