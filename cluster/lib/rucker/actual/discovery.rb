module Rucker
  module Actual

    class World

      def refresh!
        refresh_containers!
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
              parent_id:  info['ParentId'],
              layer_size: info['Size'],
              size:       info['VirtualSize'],
              manifest:   image_manifest,
              docker_obj: docker_obj,
            }
          end
        end.flatten.compact
      end

      #
      # Containers
      #

      def refresh_containers!
        raw_ctrs = fetch_raw_containers
        binding.pry
        receive_containers(raw_ctrs)
      end

      def fetch_raw_containers
        docker_objs = Docker::Container.all('all' => 'True')
        ctr_manifests = manifest.containers_hsh
        #
        docker_objs.map do |docker_obj|
          docker_obj.names.map do |name|
            ctr_manifest = ctr_manifests[name]
            next unless ctr_manifest.present?
            ctr_manifest.simple_container_hsh.merge(
              name: name,
              manifest: ctr_manifest,
              docker_obj: docker_obj
              )
          end
        end.flatten.compact
      end

    end # Rucker::Actual::World
  end
end
