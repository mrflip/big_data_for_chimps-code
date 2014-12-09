Bundler.require(:default, :docker, :tutum)
require 'logger'
::Log = Logger.new($stderr) unless defined?(Log)
Log.level = Logger::DEBUG
RestClient.log = Log

Gorillib::Model::Field.class_eval do
  field :aka, :array, of: :symbol, default: ->(){ Array.new }, doc: 'other keys to receive into this field'
  def receive_aka(val)
    super(Array.wrap(val))
  end
end

module Rucker
  module Actual
    class TutumBase
      include Gorillib::Model
      include Gorillib::AccessorFields
      accessor_field :connection

      def self.connection
        @connection ||=
          begin
            creds = Rucker::Manifest::World.send(:credentials)['tutum.co']
            creds.present? && creds['api_key'].present? or raise ArgumentError, "No API key found in the credentials file. See Rucker::Manifest::World.credentials"
            Tutum.new(creds['username'], creds['api_key'])
          end
      end

      def handle_extra_attributes(attrs)
        attrs.symbolize_keys!
        self.class.fields.each do |fn, fld|
          fld.aka.each do |alt_fn|
            self.send("receive_#{fn}", attrs.delete(alt_fn)) if attrs.include?(alt_fn)
          end
        end
        super(attrs)
        %w[ cpu_shares deployment_strategy memory privileged run_command sequential_deployment
          autodestroy autoreplace autorestart
        ].each{|attr| attrs.delete(attr.to_sym) }
        p attrs
      end

    end

    #
    class TutumService < TutumBase
      attr_reader :connection
      field :name,           :string
      field :id,             :string, aka: :uuid
      field :tutum_uri,      :string, aka: :resource_uri, doc: '/api/v1/service/775526b3-fb65-42f9-9eea-f9ca7a810676'
      field :unique_name,    :string
      field :tags,           :array, of: :string
      field :image_repo_tag, :string, aka: :image_name
      field :image_api_tag,  :string, aka: :image_tag
      #
      field :envs,           :array, of: :string, aka: :container_envvars
      field :ports,          :array, of: Rucker::Manifest::PortBinding, aka: :container_ports
      field :state,          :symbol, doc: "Current state of the service"
      #
      field :containers,     :array, of: Whatever
      field :ctrs_current,   :integer, aka: :current_num_containers, doc: 'Number of started or stopped containers'
      field :ctrs_running,   :integer, aka: :running_num_containers, doc: 'Number of started containers'
      field :ctrs_stopped,   :integer, aka: :stopped_num_containers, doc: 'Number of stopped containers'
      field :ctrs_target,    :integer, aka: :target_num_containers,  doc: 'Number of containers designated to run'
      #
      field :created_at,     :time, aka: :deployed_datetime
      field :destroyed_at,   :time, aka: :destroyed_datetime
      field :stopped_at,     :time, aka: :stopped_datetime
      field :started_at,     :time, aka: :started_datetime
      #
      field :entrypoint,     Whatever # string or array?
      field :command,        Whatever
      #
      field :links,          :array, of: Whatever, aka: :linked_to_services
      field :links_from,     :array, of: Whatever, aka: :linked_from_services
      field :roles,          :array, of: Whatever
      field :actions,        :array, of: Whatever
      field :link_variables, Whatever

      def tutum
        self.class.connection.services
      end

      #
      # List all services
      #
      def self.all()
        resp = connection.services.list
        resp.present? && resp['objects'].present? or raise "Unreadable response: #{raws}"
        raws = resp.delete('objects')
        p resp
        svcs = raws.map do |raw|
          self.receive(raw)
        end
      end

      #
      # Repopulate with updated attributes
      #
      def refresh!
        self.receive!(tutum.get(id))
      end

      def stop
        tutum.stop(id)
      end

      def start
        tutum.start(id)
      end

      def adjust_count(new_count)
        self.target_num_containers = new_count
        tutum.update(target_num_containers: target_num_containers)
      end

      #
      # Upgrade the service to the latest version of the image tag
      #
      def redeploy
        tutum.redeploy(id)
      end

      #
      # Terminate service's existence
      #
      def remove
        tutum.terminate(id)
        true
      end

      def logs
      end

      def self.create(ctr)
        hsh = {
          name:            ctr.name,
          image:           ctr.image_repo_tag,
          target_num_containers: 1,
          #
          # entrypoint:      ctr.entrypoint,
          # container_ports: ports_hsh(ctr),
          container_envvars: [],
          # linked_to_service: [],
          autorestart:     'OFF',
          autoreplace:     'OFF',
          autodestroy:     'OFF',
          # roles:           [],
          # privileged:      false,
          # tags:            [ ctr.name ],
          # sequential_deployment: false,
        }
        result = connection.services.create(hsh)
        p result
        self.receive(result)
      end

      def to_tutum_hsh
        attrs = self.attributes
        self.class.fields.each do |fn, fld|
          fld.aka.each do |alt_fn|
            attrs[alt_fn] = attrs.delete(fn)
          end
        end
        p attrs
        attrs
      end

      def self.duplicate(tut_ctr)
        result = connection.services.create(tut_ctr.to_tutum_hsh)
        self.receive(result)
      end

      # @example
      #   [{"protocol": "tcp", "inner_port": 80, "outer_port": 80}]
      def self.ports_hsh(ctr)
        ctr.ports.map do |port|
          { protocol: port.proto, inner_port: port.cport, outer_port: port.hport,
            port_name: port.desc, published: port.published?.to_s }
        end
      end

      def receive_ports(vals)
        vals.each do |val|
          if val.is_a?(Hash)
            val.symbolize_keys!
            val[:desc]  ||= val.delete(:port_name)  if val.include?(:port_name)
            val[:cport] ||= val.delete(:inner_port) if val.include?(:inner_port)
            val[:hport] ||= val.delete(:outer_port) if val.include?(:outer_port)
            val[:proto] ||= val.delete(:protocol)   if val.include?(:protocol)
            val.delete(:published)
          end
        end
        super(vals)
      end

      #
      # @example
      #   [{"to_service": "/api/v1/service/80ff1635-2d56-478d-a97f-9b59c720e513/", "name": "db"}]
      def self.links_hsh(ctr)
        ctr.linked_containers.map do |as_name, other|
          { to_service: other.id, name: as_name }
        end
      end

      # @example
      #   [{"key": "DB_PASSWORD", "value": "mypass"}]
      def self.envs_hsh
        ctr.envs.map do |env_str|
          key, val = env_str.split('=', 2)
          { key: key, value: val }
        end
      end

    end
  end
end
