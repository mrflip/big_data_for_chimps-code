module Rucker
  module Actual

    class World

      def refresh!
        refresh_images!
      end

      #
      # Images
      #

      def refresh_images!
        receive_images(fetch_raw_images)
      end

      def fetch_raw_images
        docker_objs = Docker::Image.all
        image_manifests = manifest.images
        docker_objs.map do |docker_obj|
          info = docker_obj.info
          info['RepoTags'].map do |tagged_name|
            next if tagged_name == '<none>:<none>' # all of ours are tagged
            image_manifest = image_manifests[tagged_name]
            next unless image_manifest.present?
            raw_image = {
              name:       tagged_name,
              id:         info['id'],
              created_at: info['Created'],
              size:       info['VirtualSize'],
              manifest:   image_manifest,
              docker_obj: docker_obj,
              # parent_id:  info['ParentId'],
              # layer_size: info['Size'],
            }
          end
        end.flatten.compact
      end

    end # Rucker::Actual::World
  end
end
