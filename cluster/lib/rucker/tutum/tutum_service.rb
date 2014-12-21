module Rucker
  module Tutum
    #
    class TutumService < ::Tutum::Service
      #
      # Actions
      #


      # All names this may be known by
      def names() [ name.to_sym ] ; end

      # def exists?
      #   not [:terminated, :terminating, :absent].include?(state)
      # end

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
          name:            ctr.name,
          image:           ctr.image_repo_tag,
          target_num_containers: 1,
          #
          container_ports:   ports_hsh(ctr),
          container_envvars: envs_hsh(ctr),
          linked_to_service: links_hsh(ctr),
          autorestart:     'OFF',
          autoreplace:     'OFF',
          autodestroy:     'OFF',
          tags:            [ { name: ctr.name } ],
          # roles:           [],
          # privileged:      false,
          # sequential_deployment: false,
        }
        hsh[:entrypoint]  = Shellwords.join(ctr.entrypoint) if ctr.entrypoint.present?
        hsh[:run_command] = Shellwords.join(ctr.entry_args) if ctr.entry_args.present?
        self.create(hsh)
      end

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

      # def receive_state(val)
      #   val = val.to_s.downcase.gsub(/[^\w]+/, '_')
      #   val =
      #     case val
      #     when /partly.*runn/ then :partly
      #     when /terminat.*/   then :absent
      #     else                     val
      #     end
      #   super(val)
      # end
      #
      # def receive_ports(vals)
      #   vals.each do |val|
      #     if val.is_a?(Hash)
      #       val.symbolize_keys!
      #       val[:desc]  ||= val.delete(:port_name)  if val.include?(:port_name)
      #       val[:cport] ||= val.delete(:inner_port) if val.include?(:inner_port)
      #       val[:hport] ||= val.delete(:outer_port) if val.include?(:outer_port)
      #       val[:proto] ||= val.delete(:protocol)   if val.include?(:protocol)
      #       val.delete(:published)
      #     end
      #   end
      #   super(vals)
      # end

      # Init            The service has been created and has no deployed containers yet. Possible actions in this state: start, terminate.
      # Starting        All containers for the service are either starting or already running. No actions allowed in this state.
      # Running         All containers for the service are deployed and running. Possible actions in this state: stop, redeploy, terminate.
      # Partly running  One or more containers of the service are deployed and running. Possible actions in this state: stop, redeploy, terminate.
      # Scaling         The service is either deploying new containers or destroying existing ones responding to a scaling request. No actions allowed in this state.
      # Redeploying     The service is redeploying all its containers with the updated configuration. No actions allowed in this state.
      # Stopping        All containers for the service are either stopping or already stopped. No actions allowed in this state.
      # Stopped         All containers for the service are stopped. Possible actions in this state: start, redeploy, terminate.
      # Absent          (Terminating) All containers for the service are either being terminated or already terminated. No actions allowed in this state.
      # Absent          (Terminated)  The service and all its containers have been terminated. No actions allowed in this state.
      # Not running     There are no containers to be deployed for this service. Possible actions in this state: terminate.

      # def handle_extra_attributes(attrs)
      #   attrs.symbolize_keys!
      #   self.class.fields.each do |fn, fld|
      #     fld.aka.each do |alt_fn|
      #       self.send("receive_#{fn}", attrs.delete(alt_fn)) if attrs.include?(alt_fn)
      #     end
      #   end
      #   super(attrs)
      #   %w[ cpu_shares deployment_strategy memory privileged run_command sequential_deployment
      #     autodestroy autoreplace autorestart
      #   ].each{|attr| attrs.delete(attr.to_sym) }
      # end
      #
      # EXTENDED_ATTRS = [:actions, :bindings, :envs, :container_ids,
      #   :linked_envs, :links, :links_from, :roles,
      #   :tags, :webhooks, ]
      # # These require an extra get before we know their value
      # def read_unset_attribute(field_name)
      #   if EXTENDED_ATTRS.include?(field_name)
      #     refresh!
      #     return read_attribute(field_name) if attribute_set?(field_name)
      #   end
      #   super
      # end
      #
      # # Stop the service's containers
      # #
      # def stop
      #   connection.services.stop(id)
      #   forget
      # end
      #
      # # Start the service's containers
      # #
      # def start
      #   unless [:init, :stopped].include?(state)
      #     return(warn "Cannot start #{self.name} from state #{state}")
      #   end
      #   connection.services.start(id)
      #   forget
      # end
      #
      # # Change the number of containers running
      # #
      # def adjust_count(new_count)
      #   self.target_num_containers = new_count
      #   connection.services.update(target_num_containers: target_num_containers)
      #   forget
      # end
      #
      # # Upgrade the service to the latest version of the image tag
      # #
      # def redeploy
      #   connection.services.redeploy(id)
      #   forget
      # end
      #
      # # Terminate service's existence
      # #
      # def remove(opts={})
      #   connection.services.terminate(id)
      #   forget
      # end
      #
      # # See logs
      # #
      # def logs
      # end
      #
      # # Create another service just like this one
      # #
      # def self.duplicate(tut_ctr)
      #   result = connection.services.create(tut_ctr.to_tutum_hsh)
      #   self.receive(result)
      # end


      # def to_tutum_hsh
      #   attrs = self.attributes
      #   self.class.fields.each do |fn, fld|
      #     fld.aka.each do |alt_fn|
      #       attrs[alt_fn] = attrs.delete(fn)
      #     end
      #   end
      #   attrs
      # end

      def id()  uuid ; end

      def linked_envs()  link_variables ; end
      def ctrs_current() current_num_containers() ;  end
      def ctrs_running() running_num_containers() ;  end
      def ctrs_stopped() stopped_num_containers() ;  end
      def ctrs_target()  target_num_containers()  ;  end

      # field :name,           :symbol
      # field :id,             :string,  aka: :uuid,                  doc: 'A unique identifier generated automatically on creation'
      # field :tutum_uri,      :string,  aka: :resource_uri,          doc: 'The unique API endpoint that represents the container'
      # field :unique_name,    :string,                               doc: 'A unique name automatically assigned based on the user provided name'
      # field :image_repo_tag, :string,  aka: :image_name,            doc: 'The Docker image name and tag of the container'
      # field :image_uri,      :string,  aka: :image_tag,             doc: 'Resource URI of the image (including tag) of the container'
      # field :state,          :symbol,                               doc: "Current state of the container: Init, Starting, Running, Stopping, Stopped, Terminating, Terminated"
      # #
      # field :envs,           :array,   of: :string, aka: :container_envvars
      # collection :ports,     Rucker::Manifest::PortBindingCollection, aka: :container_ports
      # #
      # #
      # field :created_at,     :time,    aka: :deployed_datetime
      # field :destroyed_at,   :time,    aka: :destroyed_datetime
      # field :stopped_at,     :time,    aka: :stopped_datetime
      # field :started_at,     :time,    aka: :started_datetime
      # #
      # field :entrypoint,     Whatever,                              doc: 'Entrypoint used on the container on launch'
      # field :command,        Whatever,                              doc: ''
      # #
      # field :roles,          :array,   of: Whatever,                doc: 'List of Tutum roles asigned to this container'
      # field :actions,        :array,   of: Whatever,                doc: 'Run command used on the container on launch'
      # field :linked_envs,    Whatever, aka: :link_variables
      # #
      # field :volumes,        :array,  of: Whatever, aka: :bindings, doc: 'A list of volume bindings that the container has mounted'
      #
      # # # Not yet: cpu_shares deployment_strategy memory privileged run_command
      # # #    autodestroy autoreplace autorestart
      #
      # # Service attrs
      # #
      # field :container_ids,  :array,   of: Whatever, aka: :containers, doc: 'Full URIs for the containers in this service.'
      # field :ctrs_current,   :integer, aka: :current_num_containers, doc: 'Number of started or stopped containers'
      # field :ctrs_running,   :integer, aka: :running_num_containers, doc: 'Number of started containers'
      # field :ctrs_stopped,   :integer, aka: :stopped_num_containers, doc: 'Number of stopped containers'
      # field :ctrs_target,    :integer, aka: :target_num_containers,  doc: 'Number of containers designated to run'
      # field :links,          :array,   of: Whatever, aka: :linked_to_service
      # field :links_from,     :array,   of: Whatever, aka: :linked_from_service
      # field :tags,           :array,   of: :string
      # # # Not yet: sequential_deployment
      #
      # # Container attrs
      # #
      # field :service_id,     :string, aka: :service, doc: 'The resource URI of the service which this container is part of'
      # field :exit_code,      :integer, doc: 'The numeric exit code of the container (if applicable, null otherwise)'
      # field :exit_msg,       :string, aka: :exit_code_msg, doc: 'A string representation of the exit code of the container (if applicable, null otherwise)'
      # field :node_id,        :string, doc: 'The resource URI of the node where this container is running'
      # field :public_fqdn,    :string, doc: 'The external hostname (FQDN) of the container'
      #
      # accessor_field :containers, :array, writer: false

      # # List all services
      # #
      # def self.all(opts={})
      #   resp = connection.services.list
      #   resp.present? && (not resp['objects'].nil?) or raise "Unreadable response: #{resp}"
      #   raws = resp.delete('objects')
      #   svcs = raws.map do |raw|
      #     self.receive(raw)
      #   end
      # end
      #
      # # Repopulate with updated attributes
      # #
      # def refresh!
      #   forget
      #   self.receive!(connection.services.get(id))
      #   main_ctr_id = self.container_ids.first
      #   if main_ctr_id.present?
      #     hsh = connection.containers.get(main_ctr_id)
      #     self.receive!(hsh.slice(:exit_code, :exit_code_msg, :node_id, :public_fqdn))
      #   end
      #   self
      # end
      # def forget()
      #   unset_containers
      # end
      #
      # def containers
      #   return @containers if instance_variable_defined?(:@containers)
      #   @containers = container_ids.map{|cid| connection.containers.get(cid) }
      # end

    end
  end
end
