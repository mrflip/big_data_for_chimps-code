module Docker
  #
  # We're breaking the promise of caching nothing on the justification that we
  # are executing high-level care in the orchestration level.
  #
  Container.class_eval do


    # # Basic Attributes
    #
    # name                  -  cs - name for the container
    # (c/)Image             - Gc  - String value containing the image name
    # Id                    - L   - ID
    # SizeRw                - L   -
    # SizeRootFs            - L   -
    # Created               - L   -
    # Status                - L   - "Exit <code>", "Up <time>", ???
    # State                 - G   - { Running, Pid, ExitCode, StartedAt, Ghost }
    # Path                  - G   - ...
    # ContainerIDFile       - G   - ...
    #
    # # Container command to execute
    #
    # (c/)User              - Gc  - A string value containg the user to use inside the container.
    # (c/)WorkingDir        -  c  - A string value containing the working dir for commands to run in.
    # SysInitPath           - G   - ...
    # (c/)Env               - Gc  - A list of environment variables in the form of VAR=value
    # (c/)Cmd               - Gc  - Command to run specified as a string or an array of strings.
    # Command               - L   - Command that was run, as a single string
    # Args                  - G   - Arguments passed to the command
    # Entrypoint            -  c  - Set the entrypoint for the container a a string or an array of strings
    #
    # # Client-side Run state options
    #
    # (c/)AttachStdin       - Gc  - Boolean value, attaches to stdin.
    # (c/)AttachStdout      - Gc  - Boolean value, attaches to stdout.
    # (c/)AttachStderr      - Gc  - Boolean value, attaches to stderr.
    # (c/)OpenStdin         - Gc  - Boolean value, opens stdin,
    # (c/)StdinOnce         - Gc  - Boolean value, close stdin after the 1 attached client disconnects.
    # (c/)Tty               - Gc  - Boolean value, Attach standard streams to a tty, including stdin if it is not closed.
    #
    # # Volumes and VolumesFrom
    #
    # (c/)Volumes           - Gc  - An object mapping mountpoint paths (strings) inside the container to empty objects.
    # Volumes               - G   - ...
    #
    # (hc/)Binds            - Gcs - A list of volume bindings for this container. Each volume binding is a string of the form container_path (to create a new volume for the container), host_path:container_path (to bind-mount a host path into the container), or host_path:container_path:ro (to make the bind-mount read-only inside the container).
    # (hc/)VolumesFrom      -  cs - A list of volumes to inherit from another container. Specified in the form <container name>[:<ro|rw>]
    #
    # # Networking
    #
    # NetworkSettings       - G   - { IpAddress, IpPrefixLen, Gateway, Bridge, PortMapping }
    # ResolvConfPath        - G   - ...
    # Ports                 - L   - A Summary of the ports in the form of { "PrivatePort": x, "PublicPort": x, "Type": x, "Ip": x }
    # ExposedPorts          -  c  - An object mapping ports to an empty object in the form of: "ExposedPorts": { "<port>/<tcp|udp>: {}" }
    # (PortSpecs)           - G
    # (c/)Hostname          - Gc  - A string value containing the desired hostname to use for the container.
    # Domainname            -  c  - A string value containing the desired domain name to use for the container.
    # (hc/)Links            - Gcs - A list of links for the container. Each link entry should be of of the form "container_name:alias".
    # (hc/)PortBindings     - Gcs - A map of exposed container ports and the host port they should map to. It should be specified in the form { <port>/<protocol>: [{ "HostPort": "<port>" }] } Take note that port is specified as a string and not an integer value.
    # (hc/)PublishAllPorts  - Gcs - Allocates a random host port for all of a container's exposed ports. Specified as a boolean value.
    # (hc/)Dns              - Gcs - A list of dns servers for the container to use.
    # (hc/)DnsSearch        -  cs - A list of DNS search domains
    # (hc/)NetworkMode      -  cs - Sets the networking mode for the container. Supported values are: bridge, host, and container:<name|id>
    # NetworkDisabled       -  c  - Boolean value, when true disables neworking for the container
    #
    # # Container Capabilities
    #
    # Memory                - Gc  - Memory limit in bytes.
    # MemorySwap            - Gc  - Total memory usage (memory + swap); set -1 to disable swap.
    # CpuShares             -  c  - An integer value containing the CPU Shares for container (ie. the relative weight vs othercontainers). CpuSet - String value containg the cgroups Cpuset to use.
    # (hc/)RestartPolicy    -  cs - The behavior to apply when the container exits. The value is an object with a Name property of either "always" to always restart or "on-failure" to restart only when the container exit code is non-zero. If on-failure is used, MaximumRetryCount controls the number of times to retry before giving up. The default is not to restart. (optional)
    # (hc/)Privileged       - Gcs - Gives the container full access to the host. Specified as a boolean value.
    # (hc/)LxcConf          - Gcs - LXC specific configurations. These configurations will only work when using the lxc execution driver.
    # (hc/)CapAdd           - Gcs - A list of kernel capabilties to add to the container.
    # (hc/)Capdrop          - Gcs - A list of kernel capabilties to drop from the container.
    # (hc/)Devices          -  cs - A list of devices to add to the container specified in the form { "PathOnHost": "/dev/deviceName", "PathInContainer": "/dev/deviceName", "CgroupPermissions": "mrw"}
    # SecurityOpts          -  c  - A list of string values to customize labels for MLS systems, such as SELinux.
    
    # Remove memoized last-seen info so that future calls will force a fetch
    def forget
      remove_instance_variable :@ext_info if instance_variable_defined?(:@ext_info)
      return self
    end

    #
    # These things come back for free with the call to .all
    #

    def self.raw_create_hsh(ctr)
      pub_ports = ctr.ports.published_creation_hshs
      exp_ports = ctr.ports.exposed_creation_hshs
      vol_spec = {}
      ctr.volumes.each{|vol| vol_spec[vol.gsub(/:.*/,'')] = Hash.new }
      {
        'name'              => ctr.name,
        'Image'             => ctr.image_name,
        'Entrypoint'        => ctr.entrypoint,
        'Cmd'               => ctr.entry_args,
        'Hostname'          => ctr.hostname,
        'Volumes'           => vol_spec,
        'HostConfig' =>{
          'Links'           => ctr.links.map(&:to_s), # 'container_name:alias'
          'Binds'           => ctr.volumes,           # 'path', 'hpath:cpath', 'hpath:cpath:ro'
          'VolumesFrom'     => ctr.volumes_from,      # ctr_name:ro or ctr_name:rw
          'RestartPolicy'   => {},                    # or {'Name'=>'always'} or { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
          'ExposedPorts'    => exp_ports,             # { "<port>/<tcp|udp>: {}" }
          'PortBindings'    => pub_ports,             # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
          'PublishAllPorts' => true,
        }
      }
    end

    def self.create_from_manifest(ctr)
      create(raw_create_hsh(ctr))
    end

    def raw_start_hsh(ctr)
      pub_ports = ctr.ports.published_creation_hshs
      {
        'Links'           => ctr.links.map(&:to_s),   # 'container_name:alias'
        'Binds'           => ctr.volumes,             # 'path', 'hpath:cpath', 'hpath:cpath:ro'
        'VolumesFrom'     => ctr.volumes_from,        # ctr_name:ro or ctr_name:rw
        'RestartPolicy'   => {'Name'=>'always'},      # or { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
        'PortBindings'    => pub_ports,               # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
        'PublishAllPorts' => true,
      }
    end

    def start_from_manifest(ctr)
      start(raw_start_hsh(ctr))
    end

    def stop_from_manifest(ctr)
      stop()
    end

    def parse_status_str(str)
      case str
      when %r{\AExited \((-?\d+)\) (.*)\z} then { state: :stopped, ago_str: $2, exit_code: $1.to_i}
      when %r{\AUp (.*?) \(Paused\)\z}   then { state: :paused,  ago_str: $1 }
      when %r{\AUp (.*)\z}               then { state: :running, ago_str: $1 }
      when %r{restart ?(.*)}i            then { state: :restart, ago_str: $1 } # don't know what this looks like
      else
        warn "Can't parse status string #{str}" ; { state: :unknown }
      end
    end

    # Alternate names for this container, without initial slashes
    # @return Array[String]
    def names()           @info['Names']   ; end

    # Name for the image used to create this container
    def image_name()      @info['Image']   ; end

    # Command that the container runs
    def command_str()     @info['Command'] ; end

    # Time the object was created
    def created_at()      @info['Created'] ; end

    # A readable description of the object's state
    def status_str()      @info['Status']  ; end
    # "SizeRw":12288,
    # "SizeRootFs":0

    FIXUP_NAME_RE = %r{^/}
    def names()
      info['Names'].map{|name| name.gsub(FIXUP_NAME_RE, '').to_sym }
    end

    def ports()
      info['Ports'].map do |port_hsh|
        { bind: port_hsh["IP"], cport: port_hsh['PrivatePort'], hport: port_hsh['PublicPort'], proto: port_hsh['Type'] }
      end
    end

    #
    # These require an extra call to get the detailed info
    #

    # Memoized request for detailed values
    def ext_info
      @ext_info  ||= json
    rescue Docker::Error::DockerError => err
      @ext_info = { 'NetworkSettings' => {}, 'Config' => {}, 'HostConfig' => {}, 'State' => {} }
    end

    def hostname()        ext_info['Hostname'] ;  end
    def ip_address()      ext_info['NetworkSettings']['IPAddress'] ;  end
    def image_id()        ext_info['Image']               ; end
    # As requested at config time
    def conf_image_name() ext_info['Config']['Image'] ; end
    def conf_volumes()    ext_info['Config']['Volumes'].keys   || Array.new rescue Array.new ; end
    def volumes_from()    ext_info['HostConfig']['VolumesFrom'] || Array.new ; end
    # runtime ing
    def exit_code()       ext_info['State']['ExitCode']   ; end
    def started_at()      ext_info['State']['StartedAt']  ; end
    def stopped_at()      ext_info['State']['FinishedAt'] ; end
    # also: ghost, pid

    FIXUP_LINK_NAME_RE = %r{^.*/(.*?):.*}
    def links
      links = ext_info['HostConfig']['Links'] or return Array.new
      links.map{|link| link.gsub(FIXUP_LINK_NAME_RE, '\1') }
    end

    # State of the machine: :running, :paused, :restart, :stopped, or :absent
    # @return [:running, :paused, :restart, :stopped, :absent]
    def state()
      state_hsh = ext_info['State']
      case
      when state_hsh.blank?        then :absent
      when state_hsh['Running']    then :running
      when state_hsh['Restarting'] then :restart
      when state_hsh['Paused']     then :paused
      else                              :stopped
      end
    end

    # Volume status
    def volumes()
      ext_info['Volumes'].map do |name, path|
        writeable = ext_info["VolumesRW"][name]
        { name: name, path: path, writeable: writeable }
      end
    end

    def ports_from_ext
      pbs = []
      bound_ports = ext_info['HostConfig']['PortBindings'] or return []
      bound_ports.each do |key, bindings|
        cport, proto = key.split('/');
        bindings.each do |info|
          pb = { cport: cport, proto: proto }
          pb[:hport] = info['HostPort'] if info['HostPort'].present?
          pb[:bind]  = info['HostIp']   if info['HostIp'].present?
          pbs << pb
        end
      end
      ext_info['Config']['ExposedPorts'].each do |key, dummy|
        next if bound_ports.include?(key)
        cport, proto = key.split('/');
        pbs << { cport: cport, proto: proto }
      end
      pbs.uniq
    end


    # def simple_container_hsh
    #   state_hsh = parse_status_str(status_str)
    #   {
    #     names:       names,
    #     id:          id,
    #     created_at:  created_at,
    #     image_name:  image_name,
    #     status_str:  status_str,
    #     ports:       ports,
    #     state:       state_hsh[:state],
    #     # command_str: command_str,
    #   }
    # end
    # 
    # def container_hsh
    #   simple_container_hsh.merge(
    #     ports:         ports_from_ext,
    #     links:         links,
    #     started_at:    started_at,
    #     stopped_at:    stopped_at,
    #     ip_address:    ip_address,
    #     image_id:      image_id,
    #     volumes:       volumes,
    #     volumes_from:  volumes_from,
    #     state:         state,
    #   )
    # end
    
  end
end
