module Rucker
  module Tutum
    #
    class TutumService < ::Tutum::Service

      # ===========================================================================
      #
      # Properties
      #

      # All names this may be known by
      def names() [ underbar_name, dashed_name ] ; end
      def underbar_name() ; name.to_s.gsub(/_/, '-').to_sym    ; end
      def dashed_name() ;   name.to_s.gsub(/_/, '-').to_sym    ; end

      def id()  uuid ; end

      def linked_envs()  link_variables ; end
      def ctrs_current() current_num_containers() ;  end
      def ctrs_running() running_num_containers() ;  end
      def ctrs_stopped() stopped_num_containers() ;  end
      def ctrs_target()  target_num_containers()  ;  end

      def exit_code
        stopped_at.nil? ? nil : 0
      end

      # ===========================================================================
      #
      # Actions
      #

      def self.all
        list()
      end

      def start_using_manifest(ctr)
        start
      end

      def stop_using_manifest(ctr)
        stop
      end

      def remove_using_manifest(ctr)
        terminate
      end

      # Create a service from a manifest
      #
      def self.create_using_manifest(ctr)
        hsh = {
          name:              ctr.dashed_name,
          image:             ctr.image_repo_tag,
          target_num_containers: 1,
          #
          container_ports:   ports_hsh(ctr),
          container_envvars: envs_hsh(ctr),
          linked_to_service: links_hsh(ctr),
          bindings:          vols_hsh(ctr),
          autorestart:       'OFF',
          autodestroy:       'OFF',
          # sequential_deployment: false,
          roles:             [],
          # privileged:      false,
          tags:              [ { name: ctr.name } ],
        }
        hsh[:entrypoint]  = Shellwords.join(ctr.entrypoint) if ctr.entrypoint.present?
        hsh[:run_command] = Shellwords.join(ctr.entry_args) if ctr.entry_args.present?
        p hsh
        self.create(hsh)
      end

      # ===========================================================================
      #
      # Facade

      # @example
      #   [{"protocol": "tcp", "inner_port": 80, "outer_port": 80}]
      def self.ports_hsh(ctr)
        ctr.ports.map do |port|
          { protocol: port.proto, inner_port: port.cport, outer_port: port.hport,
            port_name: port.desc, published: port.published?.to_s }
        end
      end

      # @example
      #   [{"to_service": "/api/v1/service/80ff1635-2d56-478d-a97f-9b59c720e513/", "name": "db"}]
      def self.links_hsh(ctr)
        ctr.linked_containers.map do |as_name, other|
          { to_service: other.actual.resource_uri,
            name: as_name
          }
        end
      end

      # @example
      #   [{"key": "DB_PASSWORD", "value": "mypass"}]
      def self.envs_hsh(ctr)
        ctr.envs.map do |env_str|
          key, val = env_str.split('=', 2)
          { key: key, value: val }
        end
      end

      def self.vols_hsh(ctr)
        ctr.volumes.map do |vol|
          h_path, c_path, perms = (vol =~ /:/ ? vol.split(':',3) : [nil, vol, nil])
          hsh = { container_path: c_path }
          hsh[:host_path] = h_path if h_path
          hsh[:rewritable] = true  if perms != 'ro'
          hsh
        end
      end

    end
  end
end
