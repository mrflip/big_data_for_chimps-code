# -*- coding: utf-8 -*-
module Rucker
  class Dockerer
    include Gorillib::Model
    include Gorillib::Model::PositionalFields

    def type_name
      Gorillib::Inflector.demodulize(self.class.name.to_s)
    end

    def desc_state
      states = Array.wrap(state)
      str = "#{type_name} #{self.name} "
      case
      when states == []       then str << "has nothing defined that it can report on"
      when states.length == 1 then str << "is consistently #{states.first}"
      else
        fin = states.pop
        str << "is inconsistent: a mixture of #{states.join(', ')} and #{fin} states"
      end
      str
    end
  end

  class PortBinding
    field :desc,  :string,  doc: "Description of the port"
    field :hport, :integer, doc: "Host port to bind"
    field :cport, :integer, doc: "Container port to bind"
    field :proto, :string,  doc: "Protocol: UDP or TCP", default: 'tcp'
    field :bind,  :string,  doc: "IP address this port binds to"

    # Should this port be published to the docker host, or only exposed to
    # containers that explicitly link it?
    def published?
      !! hport
    end

    def to_s
      [ (bind  ? "#{bind}:"      : nil),
        (hport ? "#{hport}:"     : nil),
        cport,
        (proto == 'udp' ? '/udp' : nil) ].compact.join
    end

    def cport_proto
      "#{cport}/#{proto}"
    end

    # bind:hport:cport~desc or bind::cport~desc
    BIND_HC_RE     = %r{\A (\d+\.\d+\.\d+\.\d+) : (\d+)? : (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    # hport:cport~desc
    HPORT_CPORT_RE = %r{\A                        (\d+)  : (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    # cport~desc
    CPORT_RE       = %r{\A                                 (\d+) (?:/(tcp|udp))? (?:~([a-z0-9_]+))? \z}x
    #
    def self.parse_portstr(str)
      # Could I do this with one regexp? probably, but I wouldn't want to read the conditionals that would ensue
      case str
      when CPORT_RE       then {                      cport: $3, proto: ($4|'tcp'), desc: $5 }
      when HPORT_CPORT_RE then {           hport: $2, cport: $3, proto: ($4|'tcp'), desc: $5 }
      when BIND_HC_RE     then { bind: $1, hport: $2, cport: $3, proto: ($4|'tcp'), desc: $5 }
      else
        warn "Can't parse port description #{str}"
        return str
      end
    end

    def self.receive(val)
      super( val.is_a?(String) ? parse_portstr(val) : val)
    end

    def collection_key()        to_s ; end
    def set_collection_key(key) receive!(parse_portstr(key)); end
  end

  class PortBindingCollection < KeyedCollection
    def exposed_creation_hshs
      # reject(|port| port.published? ).
      clxn.map{|port| { port.cport_proto => {} } }
    end
    def published_creation_hshs
      hsh = Hash.new{|h,v| h[v] = [] } # auto-vivify
      clxn.select{|port| port.published? }.each do |port|
        hsh[port.cport_proto] << { 'HostPort' => port.hport.to_s }
      end
      hsh
    end
  end

  class Container < Dockerer
    field :name,         :symbol
    field :image_name,   :string
    field :hostname,     :string, doc: "the desired hostname to use for the container"
    #
    field :entrypoint,   :string
    field :volumes_from, :array, of: :string, default: ->{ [] }
    field :volumes,      :array, of: :string, default: ->{ [] }
    field :links,        :array, of: :string, default: ->{ [] }
    field :exposes,      :array, of: :string, default: ->{ [] }
    field :envs,         :array, of: :string, default: ->{ [] }
    field :entry_args,   :array, of: :string, default: ->{ [] }

    collection :ports,   PortBindingCollection, item_type: PortBinding

    def receive_image_name(val)
      super
      self.image_name = Rucker::Common::Image.normalize_name(image_name)
    end

    def run(opts={})
      Rucker::ContainerRunner.run(self, opts)
    end

    def start(opts={})
      Rucker::ContainerRunner.start(self, opts)
    end

    def rm(opts={})
      Rucker::ContainerRunner.rm(name, opts)
    end

    def stop(opts={})
      Rucker::ContainerRunner.stop(name, opts)
    end

    def diff(opts={})
      Rucker::ContainerRunner.diff(name, opts)
    end

    def commit(dest_image_name, opts={})
      Rucker::ContainerRunner.commit(name, dest_image_name, opts)
    end

    def docker_inspect
      Rucker::ContainerRunner.docker_inspect(self.name)
    end

    #
    #
    #

    def published_ports
      ports.select{|port| port }
    end

    def raw_creation_hsh
      pub_ports = ports.published_creation_hshs
      exp_ports = ports.exposed_creation_hshs
      {
        'name'              => name,
        'Image'             => image_name,
        'Entrypoint'        => entrypoint,
        'Cmd'               => entry_args,
        'Volumes'           => volume_spec,
        'Hostname'          => hostname,
        'HostConfig' =>{
          'Links'           => links.map(&:to_s),  # 'container_name:alias'
          'Binds'           => volumes,            # 'path', 'hpath:cpath', 'hpath:cpath:ro'
          'VolumesFrom'     => volumes_from,       # ctr_name:ro or ctr_name:rw
          'RestartPolicy'   => {'Name'=>'always'}, # or { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
          'ExposedPorts'    => exp_ports,          # { "<port>/<tcp|udp>: {}" }
          'PortBindings'    => pub_ports,          # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
          'PublishAllPorts' => true,               #
        }
      }
    end

    def raw_start_hsh
      pub_ports = ports.published_creation_hshs
      {
        'Links'           => links.map(&:to_s),  # 'container_name:alias'
        'Binds'           => volumes,            # 'path', 'hpath:cpath', 'hpath:cpath:ro'
        'VolumesFrom'     => volumes_from,       # ctr_name:ro or ctr_name:rw
        'RestartPolicy'   => {'Name'=>'always'}, # or { 'Name' => 'on-failure', 'MaximumRetryCount' => count }
        'PortBindings'    => pub_ports,          # { <port>/<protocol>: [{ "HostPort": "<port>" }] } -- port is a string
        'PublishAllPorts' => true,               #
      }
    end


    #
    # Runtime Information
    #

    def docker_info
      return @docker_info if instance_variable_defined?(:@docker_info)
      @docker_info ||= Rucker::ContainerRunner.docker_info(self.name).first
    end
    def docker_info=(info) @docker_info = info ; end

    def ip_address
      return unless docker_info.present?
      docker_info[:NetworkSettings][:IPAddress]
    end

    def full_id()
      return unless docker_info.present?
      docker_info[:Id]
    end
    def id() full_id[0..12] ; end

    def full_image_id()
      return '' unless docker_info.present?
      docker_info[:Image]
    end
    def image_id()  full_image_id[0..12] ; end

    def real_image_name
      return docker_info[:Config][:Image] if docker_info.present?
      read_attribute(:image_name)
    end

    def real_links
      return [] unless docker_info.present?
      lls = docker_info[:HostConfig][:Links] or return Array.new
      lls.map{|ll| ll.gsub(%r{^.*/(.*?):.*}, '\1') }
    end

    # Volumes from as actually reported
    def real_volumes_from
      return [] unless docker_info.present?
      docker_info[:HostConfig][:VolumesFrom] || Array.new
    end

    # Volumes as actually reported by docker
    def real_volumes
      return [] unless docker_info.present?
      docker_info[:Config][:Volumes].keys || Array.new rescue Array.new
    end

    # All volumes, shared or not
    def all_volumes
      return [] unless docker_info.present?
      docker_info[:Volumes].keys || Array.new rescue Array.new
    end

    def ports_info
      return @ports_info if instance_variable_defined?(:@ports_info)
      exposed = docker_info[:Config][:ExposedPorts]     || Hash.new rescue Hash.new
      on_host = docker_info[:HostConfig][:PortBindings] || Hash.new rescue Hash.new
      network = docker_info[:NetworkSettings][:Ports]   || Hash.new rescue Hash.new
      names = [exposed.keys, on_host.keys, network.keys].flatten.uniq.sort
      @ports_info = names.hashify do |name|
        { exposed: (exposed[name]||[]), on_host: (on_host[name]||[]), network: (network[name]||[]) }
      end
    end

    def all_ports
      ps = ports_info.map do |pnt, info|
        p_name = pnt.to_s.gsub(%r{/.*}, '').to_i
        p_host = info[:on_host].first[:HostPort] rescue nil
        p_net  = info[:network].first[:HostPort] rescue nil
        ext   = "#{p_host}:" if p_host.present?
        ext ||= "#{p_net}~"  if p_net.present?
        ext ||= ''
        [p_name, ext]
      end.sort_by(&:first)
      ps.map{|pn, ext| [ext, pn].join }
    end

    def host_ports
      ps = ports_info.map do |pnt, info|
        info[:on_host].first[:HostPort] rescue nil
      end.compact_blank.map(&:to_i).sort
    end

    def state_info
      return @state_info if instance_variable_defined?(:@state_info)
      if docker_info.blank?
        return @state_info = { state: :absent }
      end
      state_hsh = docker_info[:State]
      @state_info =
        case
        when state_hsh[:Running]    then { state: :running,    time: state_hsh[:StartedAt],  started_at: state_hsh[:StartedAt], finished_at: state_hsh[:FinishedAt], }
        when state_hsh[:Restarting] then { state: :restart, time: state_hsh[:StartedAt],  started_at: state_hsh[:StartedAt], finished_at: state_hsh[:FinishedAt], }
        when state_hsh[:Paused]     then { state: :paused,     time: state_hsh[:FinishedAt], started_at: state_hsh[:StartedAt], finished_at: state_hsh[:FinishedAt], }
        else                             { state: :stopped,    time: state_hsh[:FinishedAt], started_at: state_hsh[:StartedAt], finished_at: state_hsh[:FinishedAt], }
        end
    end

    def state()      state_info[:state] || :nil_which_should_not_happen_wtf ; end
    def state_time() state_info[:time]  ; end

    #
    # Machinery
    #

    # used by KeyedCollection to know how to index these
    def collection_key()        name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key(key) receive_name(key) ; end
  end

  class Volume < Dockerer
    field :image_name, :string
  end

  class Cluster < Dockerer
    field :name, :symbol
    field :containers, Rucker::KeyedCollection, default: ->{ Rucker::KeyedCollection.new(item_type: Rucker::Container, belongs_to: self) }
    def container(name)   containers[name.to_sym] ; end
    def container_names() containers.keys ; end

    #
    # Commands
    #

    def run(names='all', opts={})
      containers_slice(names).each do |ctr|
        ctr.run(opts)
      end
    end

    def start(names='all', opts={})
      containers_slice(names).each do |ctr|
        ctr.start(opts)
      end
    end

    def stop(names='all', opts={})
      names = check_container_keys(names).reverse # removal is the reverse of installation
      Rucker::ContainerRunner.stop(names, opts)
    end

    def rm(names, opts={})
      names = check_container_keys(names)
      Rucker::ContainerRunner.rm(names, opts)
    end

    #
    # Info
    #

    # @return [Array[Symbol]] a sorted list of all states seen in the cluster.
    def state
      containers.map(&:state).uniq.sort
    end

    #
    # Machinery
    #

    def containers_slice(ctr_names, opts={})
      return containers.to_a if ctr_names.to_s == 'all'
      containers.slice(*check_container_keys(ctr_names, opts))
    end

    def check_container_keys(ctr_names, opts={})
      return containers.keys if ctr_names.to_s == 'all'
      ctr_names = Array.wrap(ctr_names).map(&:to_sym)
      unless opts[:ignore_extra] || containers.all_present?(ctr_names) then warn("Keys #{containers.extra_keys(ctr_names)} aren't present in this cluster, skipping") ; end
      (ctr_names & containers.keys) # intersection
    end

    # used by KeyedCollection to know how to index these
    def collection_key()        name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key(key) receive_name(key) ; end

    def image_names
      containers.map(&:image_name).uniq
    end

    def receive_containers(ctr_infos)
      cc = self.containers.receive!(ctr_infos)
    end

    # def receive_containers(ctr_infos)
    #   if ctr_infos.respond_to?(:each_pair)
    #     ctr_infos = ctr_infos.map{|name, info| info.merge(name: name) }
    #   end
    #   super ctr_infos
    # end
  end

  module Common
    module Image
      #
      def short_id()    id[0..12] ; end
      #
      def parsed_name
        @parsed_name = Rucker::Common::Image.split_name(name)
      end

      def ns()     @ns     ||= parsed_name[:ns]     ; end
      def slug()   @slug   ||= parsed_name[:slug]   ; end
      def tag()    @tag    ||= parsed_name[:tag]    ; end
      def family() @family ||= parsed_name[:family] ; end

      # used by KeyedCollection to know how to index these
      def collection_key()        name ; end
      # used by KeyedCollection to know how to index these
      def set_collection_key(key) receive_name(key) ; end

      # note: tag versions are derp-sorted: 10.2 precedes 2.0
      def comparable_name()
        [ ns.to_s, slug.to_s, (tag == 'latest' ? '' : tag.to_s) ]
      end

      IMAGE_NAME_RE = %r{\A
      (                                     # family (ns/slug)
        (?:   ([a-z0-9_]{1,30})       / )?    # ns /    ( a-z 0-9 _     ) optional, omit the /
              ([a-z0-9_\.\-]+|<none>)      )  # slug    ( a-z 0-9 - . _ )
        (?: : ([a-z0-9_\.\-]+|<none>)   )?    # : tag,  ( a-z 0-9 - . _ ) optional, omit the /
      \z}x
      def self.split_name(name)
        name.match(IMAGE_NAME_RE) or raise("Bad match")
        { name: name, ns: $2, slug: $3, tag: $4, family: $1 }
      rescue StandardError => err
        warn "Couldn't parse name #{name}: #{err}"
        { name: name, ns: nil, slug: "<unknown: #{name}>", tag: nil, family: "<unknown: #{name}>" }
      end

      def self.normalize_name(name)
        parsed = split_name(name)
        [parsed[:family] , ':', (parsed[:tag]||'latest') ].join
      end
    end
  end

  class Image < Dockerer
    include Rucker::Common::Image
    #
    field :id,          :string,  doc: "Hexadecimal unique id"
    field :name,        :string,  doc: "Full name -- ns/slug:tag -- for image"
    #
    field :external,    :boolean, doc: 'Is this one of your images, i.e. it should be included in a push or build?'
    field :kind,        :symbol,  doc: ':data for containers-used-as-volumes'
  end

  class ImageCollection < KeyedCollection
    # list of images with given family, sorted with 'latest' at front.
    def with_family(family)
      clxn.find_all{|key, item| item.family.to_s == family.to_s }.sort_by(&:comparable_name)
    end
  end

  class World < Dockerer
    include Gorillib::Model
    field :name,       :symbol, default: :world
    field :clusters,   :array, of: Rucker::Cluster
    collection :images, ImageCollection, item_type: Rucker::Image

    def self.load(name)
      layout = YAML.load_file Pathname.of(:cluster_layout)
      world_layout = layout[name.to_s]
      clusters = world_layout['clusters'].map do |cl_name, ctr_infos|
        Cluster.receive(name: cl_name, containers: ctr_infos)
      end
      self.new(name, clusters: clusters, images: world_layout['images'])
    end

    def image_names(cl_names='all')
      clusters_slice(cl_names).map(&:image_names).flatten.uniq
    end

    def cluster(name) clusters.find{|cl| cl.name == name } ; end
    #
    def clusters_slice(cl_names)
      return clusters if cl_names.to_s == 'all'
      Array.wrap(cl_names).map do |cl_name|
        cluster(cl_name) or abort("Can't find cluster #{cl_name} in #{self.inspect}")
      end
    end

    def container(name)
      clusters.map{|cl| cl.container(name) }.compact.first
    end
    #
    # @param names [String] names of containers to retrieve, or 'all' for all.
    # @return [Array[Rucker::Layour::Container]] requested containers across all clusters
    def containers_slice(names)
      clusters.map{|cl| cl.containers_slice(names, ignore_extra: true).to_a }.flatten.compact
    end
    #
    # @return [Hash[Rucker::Layour::Container]] Hash of name => container for all defined containers
    def containers_hsh
      hsh = {}
      clusters.each{|cl| cl.containers.each{|ctr| hsh[ctr.name] = ctr } }
      hsh
    end

    # @return [Array[Symbol]] a sorted list of all states seen in the world.
    def state
      clusters.map{|cl| cl.state }.flatten.uniq.sort
    end

    # All containers in all clusters
    def docker_info(names)
      ctrs = containers_slice(names)
      if ctrs.blank? then warn("No containers found for #{names}") ; return [] end
      # get a hash from name => info -- docker skips containers not running or stopped
      infos = Rucker::ContainerRunner.docker_info( ctrs.map(&:name) )
      infos_map = infos.inject({}) do |hsh, info|
        name = info[:Name].gsub(%r{.*/}, '').to_sym
        hsh[name] = info
        hsh
      end
      # now walk back over the asked-for containers, decorating each with its info
      ctrs.each do |ctr|
        ctr.docker_info = infos_map[ctr.name]
      end
      ctrs
    end
  end

end

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
