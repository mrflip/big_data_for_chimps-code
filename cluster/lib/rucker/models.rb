module Rucker
  class Dockerer
    include Gorillib::Model
    include Gorillib::Model::PositionalFields
  end

  class Container < Dockerer
    field :name,         :symbol
    field :image_name,   :string
    field :hostname,     :string
    field :entrypoint,   :string
    field :volumes_from, :array, default: ->{ [] }
    field :volumes,      :array, default: ->{ [] }
    field :links,        :array, default: ->{ [] }
    field :ports,        :array, default: ->{ [] }
    field :exposes,      :array, default: ->{ [] }
    field :envs,         :array, default: ->{ [] }
    field :entry_args,   :array, default: ->{ [] }

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

    def state()      state_info[:state] ; end
    def state_time() state_info[:time]  ; end

    def essentials
      { ip_address: ip_address,
      }
    end

    def dump_arr(arr, len, full=false)
      str = arr.join(',')
      if (not full) && (str.length > len)
        str = str[0..(len-3)]+'...'
      end
      str
    end

    def dump(*flds)
      full = flds.include?(:full)
      str = "%-23s\t%-7s\t%-15s\t%-15s\t%-23s" % [
        name, state, ip_address, hostname, image_name ]
      str << "\t%-12s" % image_id                          if flds.include?(:image_id)
      str << "\t%-64s" % full_image_id                     if flds.include?(:full_image_id)
      str << "\t%-23s" % dump_arr(real_volumes, 23, full)      if flds.include?(:volumes)
      str << "\t%-23s" % dump_arr(all_volumes, 23, true)       if flds.include?(:all_volumes)
      str << "\t%-23s" % dump_arr(real_volumes_from, 23, full) if flds.include?(:volumes_from)
      str << "\t%-23s" % dump_arr(real_links, 23, full)        if flds.include?(:links)
      str << "\t%-31s" % dump_arr(host_ports, 31, full)        if flds.include?(:host_ports)
      str << "\t%-31s" % dump_arr(all_ports, 31, true)         if flds.include?(:all_ports)
      str
    end

    def self.dump_header(*flds)
      str = "%-23s\t%-7s\t%-15s\t%-15s\t%-23s" % %w[ name state ip_address hostname image_name ]
      str << "\t%-12s" % 'image_id'      if flds.include?(:image_id)
      str << "\t%-64s" % 'full_image_id' if flds.include?(:full_image_id)
      str << "\t%-23s" % 'volumes'       if flds.include?(:volumes)
      str << "\t%-23s" % 'all_volumes'   if flds.include?(:all_volumes)
      str << "\t%-23s" % 'volumes_from'  if flds.include?(:volumes_from)
      str << "\t%-23s" % 'links'         if flds.include?(:links)
      str << "\t%-31s" % 'all_ports'     if flds.include?(:all_ports)
      str << "\t%-31s" % 'ports'         if flds.include?(:host_ports)
      str
    end


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
    field :containers, Rucker::KeyedCollection, default: ->{ Rucker::KeyedCollection.new(of: Rucker::Container, belongs_to: self) }
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
    def collection_key()      name ; end
    # used by KeyedCollection to know how to index these
    def set_collection_key()  receive_name(name) ; end

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

  class Image < Dockerer
    field :id,       :string
    field :name,     :string
    field :tag,      :string
    field :sz_num,   :float
    field :sz_units, :string
    field :ago,      :string
    field :cmd,      :string
    field :idx,      :integer

    def short_id()   id[0..12] ; end
    def short_cmd()  cmd[0..100] ; end
    def size()       Rucker.human_to_bytes(sz_num, sz_units) ; end

    # feae5a29ea12        About an hour ago   /bin/sh -c #(nop) COPY file:bb5fb02a76c6852b8   2.091 kB
    HISTORY_RE = /^([0-9a-f]+)\s+(.*?ago)\s+(.*?)\s+([0-9\.]+) (B|kB|MB|GB)$/
    # bd4c/baseimage       latest              db0ad19d8544        58 seconds ago      713.7 MB
    LISTING_RE = /^([\w\/\-<>]+)\s+([\w\/\-\.<>]+)\s+([0-9a-f]+)\s+(.*?ago)\s+([0-9\.]+) (B|kB|MB|GB)$/

    # name, tag, image id, created, virtual size
    def self.from_listing(str, idx = 0)
      name, tag, id, ago, sz_num, sz_units = str.chomp.match(LISTING_RE).captures rescue nil
      unless sz_units then warn "Bad match: #{str} vs #{LISTING_RE}" ; return ; end
      new(id, name, tag, sz_num, sz_units, ago, '-', idx)
    end

    # image, created, command, size
    def self.from_history(str, idx = 0)
      id, ago, cmd, sz_num, sz_units = str.chomp.match(HISTORY_RE).captures rescue nil
      return unless sz_units
      new(id, '~', '~', sz_num, sz_units, ago, cmd, idx)
    end

    PRINTF_FORMAT = %w[%3d %-23s %-15s %10d %7s\ %2s %12s %-23s %s].join("\t")

    def to_table
      PRINTF_FORMAT % [idx, name, tag, size, sz_num, sz_units, short_id, ago, short_cmd]
    end


    def self.dump_images(img_names)
      output, stderr, status  = Rucker::Runner.get_output('docker', 'images', '--no-trunc', img_names, ignore_errors: true)
      lines = output.split(/[\r\n]+/).drop(1)
      images = lines.each_with_index.map{|line, idx| Rucker::Image.from_listing(line, idx) }
      images.sort_by(&:name).each{|image| puts image.to_table }
    end

    def self.dump_history(img_name)
      output, stderr, status  = Rucker::Runner.get_output('docker', 'history', '--no-trunc', img_name)
      lines = output.split(/[\r\n]+/).drop(1)
      images = lines.reverse.each_with_index.map{|line, idx| Rucker::Image.from_history(line, idx) }
      images.sort_by(&:name).each{|image| puts image.to_table }
    end

  end

  class Layout
    include Gorillib::Model
    field :clusters,   :array, of: Rucker::Cluster
    def cluster(name) clusters.find{|cl| cl.name == name } ; end

    def self.load
      layout = YAML.load_file Pathname.of(:cluster_layout)
      clusters = layout['clusters'].map do |cl_name, ctr_infos|
        Cluster.receive(name: cl_name, containers: ctr_infos)
      end
      self.new(clusters: clusters)
    end

    def container(name)
      clusters.map{|cl| cl.container(name) }.compact.first
    end

    # All containers in all clusters
    def containers_slice(name)
      clusters.map{|cl| cl.containers_slice(name, ignore_extra: true).to_a }.flatten.compact
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

    def image_names(cl_names='all')
      clusters_slice(cl_names).map(&:image_names).flatten.uniq
    end

    def clusters_slice(cl_names)
      return clusters if cl_names.to_s == 'all'
      Array.wrap(cl_names).map do |cl_name|
        cluster(cl_name) or abort("Can't find cluster #{cl_name} in #{self.inspect}")
      end
    end
  end

end
