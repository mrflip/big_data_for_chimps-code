module Rucker
  module Actual

    #
    # We're breaking the promise of caching nothing on the justification that we
    # are executing high-level care in the orchestration level.
    #
    class TutumContainer

      def initialize
        Bundler.require(:default, :docker, :tutum)
        creds = Rucker::Manifest::World.authenticate!('tutum.co')
        @tutum = Tutum.new(creds['username'], creds['api_key'])
      end

      def create()
        {
          name:            ctr.name,
          image:           ctr.image_name,
          entrypoint:      ctr.entrypoint,
          container_ports: ports_hsh(ctr),
          container_envvars: [],
          linked_to_service: [],
          autorestart:     'OFF',
          autoreplace:     'OFF',
          autodestroy:     'OFF',
          roles:           [],
          priviledged:     false,
          tags:            [ ctr.name ],
          sequential_deployment: false,
          target_num_containers: 1,
        }
      end

      # @example
      #   [{"protocol": "tcp", "inner_port": 80, "outer_port": 80}]
      def ports_hsh(ctr)
        ctr.ports.map do |port|
          { protocol: port.proto, inner_port: port.cport, outer_port: port.hport, published: port.published? }
        end
      end

      #
      # @example
      #   [{"to_service": "/api/v1/service/80ff1635-2d56-478d-a97f-9b59c720e513/", "name": "db"}]
      def links_hsh(ctr)
        ctr.linked_containers.map do |as_name, other|
          { to_service: other.id, name: as_name }
        end
      end

      # @example
      #   [{"key": "DB_PASSWORD", "value": "mypass"}]
      def envvar_hsh
        ctr.envs.map do |env_str|
          key, val = env_str.split('=', 2)
          { key: key, value: val }
        end
      end

      # #
      # # The first set of attributes come for free with ActualContainer.all
      # #
      #
      # # Alternate names for this container, without initial slashes
      # # @return Array[String]
      # def names()           @info['Names']   ; end
      #
      # # Name for the image used to create this container
      # def image_name()      @info['Image']   ; end
      #
      # # Command that the container runs
      # def command_str()     @info['Command'] ; end
      #
      # # Time the object was created
      # def created_at()
      #   Time.at( @info['Created'] ).utc.iso8601 rescue nil
      # end
      #
      # # A readable description of the object's state
      # def status_str()      @info['Status']  ; end
      # # "SizeRw":12288,
      # # "SizeRootFs":0
      #
      # FIXUP_NAME_RE = %r{^/}
      # def names()
      #   info['Names'].map{|name| name.gsub(FIXUP_NAME_RE, '').to_sym }
      # end
      #
      # def ports()
      #   info['Ports'].map do |port_hsh|
      #     { bind: port_hsh["IP"], cport: port_hsh['PrivatePort'], hport: port_hsh['PublicPort'], proto: port_hsh['Type'] }
      #   end
      # end
      #
      # #
      # # The next set of attributes require an extra call to get the detailed info
      # #
      #
      # # Memoized request for detailed values
      # def ext_info
      #   @ext_info  ||= json
      # rescue Docker::Error::DockerError => err
      #   @ext_info = { 'NetworkSettings' => {}, 'Config' => {}, 'HostConfig' => {}, 'State' => {} }
      # end
      #
      # def hostname()        ext_info['Hostname'] ;  end
      # def ip_address()      ext_info['NetworkSettings']['IPAddress'] ;  end
      # def image_id()        ext_info['Image']               ; end
      # # As requested at config time
      # def conf_image_name() ext_info['Config']['Image'] ; end
      # def conf_volumes()    ext_info['Config']['Volumes'].keys   || Array.new rescue Array.new ; end
      # def volumes_from()    ext_info['HostConfig']['VolumesFrom'] || Array.new ; end
      # # runtime ing
      # def exit_code()       ext_info['State']['ExitCode']   ; end
      # def started_at()
      #   tm = ext_info['State']['StartedAt']
      #   (tm == '0001-01-01T00:00:00Z' ? nil : tm)
      # end
      # # @return [Time]
      # def stopped_at()
      #   tm = ext_info['State']['FinishedAt']
      #   (tm == '0001-01-01T00:00:00Z' ? nil : tm)
      # end
      # # also: ghost, pid
      #
      # FIXUP_LINK_NAME_RE = %r{^.*/(.*?):.*}
      # # Containers this is linked to (i.e. whose ports can be accessed from this one)
      # # @return [Array[String]] list of container names, with first `/` character removed
      # def links
      #   links = ext_info['HostConfig']['Links'] or return Array.new
      #   links.map{|link| link.gsub(FIXUP_LINK_NAME_RE, '\1') }
      # end
      #
      # # State of the machine: :running, :paused, :restart, :stopped, or :absent
      # # @return [:running, :paused, :restart, :stopped, :absent]
      # def state()
      #   state_hsh = ext_info['State']
      #   case
      #   when state_hsh.blank?        then :absent
      #   when state_hsh['Running']    then :running
      #   when state_hsh['Restarting'] then :restart
      #   when state_hsh['Paused']     then :paused
      #   else                              :stopped
      #   end
      # end
      #
      # # Volume status
      # # @return [Hash] hash with keys `name`, `path` and `writeable`
      # def volumes()
      #   ext_info['Volumes'].map do |name, path|
      #     writeable = !! ext_info["VolumesRW"][name]
      #     { name: name, path: path, writeable: writeable }
      #   end
      # end
      #
      # # Grabs the ports from the detailed json object
      # # @see Rucker::Manifest::PortBinding
      # # @return [Array[Hash]] hash with keys `hport`, `cport`, `proto` and
      # #   `bind`, suitable for sending to Rucker::Manifest::PortBinding
      # def ports_from_ext
      #   pbs = []
      #   bound_ports = ext_info['HostConfig']['PortBindings'] or return []
      #   bound_ports.each do |key, bindings|
      #     cport, proto = key.split('/');
      #     bindings.each do |info|
      #       pb = { cport: cport, proto: proto }
      #       pb[:hport] = info['HostPort'] if info['HostPort'].present?
      #       pb[:bind]  = info['HostIp']   if info['HostIp'].present?
      #       pbs << pb
      #     end
      #   end
      #   (ext_info['Config']['ExposedPorts'] || []).each do |key, dummy|
      #     next if bound_ports.include?(key)
      #     cport, proto = key.split('/');
      #     pbs << { cport: cport, proto: proto }
      #   end
      #   pbs.uniq
      # end
      #
      # # Remove memoized last-seen info so that future calls will force a fetch
      # def forget
      #   remove_instance_variable :@ext_info if instance_variable_defined?(:@ext_info)
      #   return self
      # end
      #
      # #
      # # These things come back for free with the call to .all
      # #
      #
      # def self.raw_create_hsh(ctr)
      #   pub_ports = ctr.ports.published_creation_hshs
      #   exp_ports = ctr.ports.exposed_creation_hshs
      #   vol_spec = {}
      #   ctr.volumes.each{|vol| vol_spec[vol.gsub(/:.*/,'')] = Hash.new }
      #   {
      #     'name'              => ctr.name,
      #     'Image'             => ctr.image_name,
      #     'Entrypoint'        => ctr.entrypoint,
      #     'Cmd'               => ctr.entry_args,
      #     'Hostname'          => ctr.hostname,
      #     'Volumes'           => vol_spec,
      #     'HostConfig' =>{
      #       'Links'           => ctr.links.map(&:to_s), # 'container_name:alias'
      #       'Binds'           => ctr.volumes,           # 'path', 'hpath:cpath', 'hpath:cpath:ro'
      #       'VolumesFrom'     => ctr.volumes_from,      # ctr_name:ro or ctr_name:rw
      #       'RestartPolicy'   => {},                    # or {'Name'=>'always'} or { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
      #       'ExposedPorts'    => exp_ports,             # { "<port>/<tcp|udp>: {}" }
      #       'PortBindings'    => pub_ports,             # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
      #       'PublishAllPorts' => true,
      #     }
      #   }
      # end
      #
      # def self.create_from_manifest(ctr)
      #   create(raw_create_hsh(ctr))
      # end
      #
      # def raw_start_hsh(ctr)
      #   pub_ports = ctr.ports.published_creation_hshs
      #   {
      #     'Links'           => ctr.links.map(&:to_s),   # 'container_name:alias'
      #     'Binds'           => ctr.volumes,             # 'path', 'hpath:cpath', 'hpath:cpath:ro'
      #     'VolumesFrom'     => ctr.volumes_from,        # ctr_name:ro or ctr_name:rw
      #     'RestartPolicy'   => {},                      # or {'Name'=>'always'} or  { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
      #     'PortBindings'    => pub_ports,               # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
      #     'PublishAllPorts' => true,
      #   }
      # end
      #
      # def start_from_manifest(ctr)
      #   start(raw_start_hsh(ctr))
      # end
      #
      # def stop_from_manifest(ctr)
      #   stop()
      # end
      #
      # def parse_status_str(str)
      #   case str
      #   when %r{\AExited \((-?\d+)\) (.*)\z} then { state: :stopped, ago_str: $2, exit_code: $1.to_i}
      #   when %r{\AUp (.*?) \(Paused\)\z}   then { state: :paused,  ago_str: $1 }
      #   when %r{\AUp (.*)\z}               then { state: :running, ago_str: $1 }
      #   when %r{restart ?(.*)}i            then { state: :restart, ago_str: $1 } # don't know what this looks like
      #   else
      #     Rucker.warn "Can't parse status string #{str}" ; { state: :unknown }
      #   end
      # end
      #
      # # @return [Hash] A hash of the essential attributes
      # def to_wire
      #   state_hsh = parse_status_str(status_str)
      #   hsh = {
      #     names:       names,
      #     id:          id,
      #     created_at:  created_at,
      #     image_name:  image_name,
      #     status_str:  status_str,
      #     ports:       ports,
      #     state:       state_hsh[:state],
      #     # command_str: command_str,
      #     _type:       self.class.name,
      #   }
      #   if @ext_info.present?
      #     hsh.merge!(
      #       ports:         ports_from_ext,
      #       links:         links,
      #       started_at:    started_at,
      #       stopped_at:    stopped_at,
      #       ip_address:    ip_address,
      #       image_id:      image_id,
      #       volumes:       volumes,
      #       volumes_from:  volumes_from,
      #       state:         state
      #       )
      #   end
      #   hsh
      # end
      #
      # #
      # # These are dupes of methods in Docker-api just to get subclasses right.
      # #
      #
      # # Return a String representation of the Container.
      # def to_s
      #   "#{self.class.name} { :id => #{self.id}, :connection => #{self.connection} }"
      # end
      #
      # # Create an Image from a Container's change.s
      # def commit(options = {})
      #   options.merge!('container' => self.id[0..7])
      #   # [code](https://github.com/dotcloud/docker/blob/v0.6.3/commands.go#L1115)
      #   # Based on the link, the config passed as run, needs to be passed as the
      #   # body of the post so capture it, remove from the options, and pass it via
      #   # the post body
      #   config = options.delete('run')
      #   hash = Docker::Util.parse_json(connection.post('/commit',
      #       options,
      #       :body => config.to_json))
      #   Rucker::Actual::ActualImage.send(:new, self.connection, hash)
      # end

    end
  end
end
