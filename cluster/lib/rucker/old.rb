module Rucker
  class Container
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

  end

  Cluster.class_eval do

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

  end

  World.class_eval do
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

  end

end



# #
# require 'gorillib/object/blank'
# require 'gorillib/object/try'
# require 'gorillib/object/try_dup'
# require 'gorillib/array/extract_options'
# require 'gorillib/hash/keys'
# require 'gorillib/hash/slice'
# require 'gorillib/string/inflector'
# require 'gorillib/exception/raisers'
# require 'gorillib/metaprogramming/concern'
# require 'gorillib/metaprogramming/class_attribute'
# #
# require 'gorillib/factories'
# # require 'gorillib/type/extended'
# require 'gorillib/model/named_schema'
# require 'gorillib/model/validate'
# require 'gorillib/model/errors'
# #
# require 'gorillib/model/base'
# require 'gorillib/model/schema_magic'
#
#
#
# module Gorillib
#   module Model
#     def extra_attributes
#       @_extra_attributes || {}
#     end
#     module ClassMethods
#       # @return [{Symbol => Gorillib::Model::Field}]
#       def fields
#         return @_fields if defined?(@_fields)
#         @_fields = ancestors.reverse.inject({}){|acc, ancestor| acc.merge!(ancestor.try(:_own_fields) || {}) }.merge(@_own_fields)
#       end
#     end
#   end
# end
#
# require 'gorillib/model/field'
# require 'gorillib/model/defaults'
