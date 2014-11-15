module Rucker
  class Dockerer
    include Gorillib::Model
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
      Rucker::ContainerRunner.run(self.attributes.merge(opts))
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
    def container(name)   containers[:name] ; end
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

    def containers_slice(ctr_names)
      return containers if ctr_names.to_s == 'all'
      containers.slice(*check_container_keys(ctr_names))
    end

    def check_container_keys(ctr_names)
      return containers.keys if ctr_names.to_s == 'all'
      ctr_names = Array.wrap(ctr_names).map(&:to_sym)
      unless containers.all_present?(ctr_names) then warn("Keys #{containers.missing_keys(ctr_names)} aren't present in this cluster, skipping") ; end
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

  class Image < Dockerer
    field :id,       :string
    field :name,     :string
    field :tag,      :string
    field :sz_num,   :integer
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

    def to_s
      PRINTF_FORMAT % [idx, name, tag, size, sz_num, sz_units, short_id, ago, short_cmd]
    end
  end

end
