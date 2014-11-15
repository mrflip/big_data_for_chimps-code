module Rucker

  module Runner
    def execute(*args, &block)
      opts = args.extract_options!
      args.map!(&:to_s)
      Rake.sh(*args) do |ok, res|
        if (not ok) && (not opts[:ignore_errors])
          abort("Command #{args.join(' ')} exited unsuccessfully (#{res.exitstatus})")
        end
      end
    end
  end

  class ImageRunner
  end

  module ContainerRunner
    extend Runner
    extend self

    def start(container, opts={})
      params = ParamList.new.add_flag('-ia', opts[:interactive])
      execute(*["docker", "start", *params, container.name], opts)
    end

    def stop(containers, opts={})
      execute(*["docker", "stop", *Array.wrap(containers)], opts)
    end

    # remove the given containers
    # @param containers [Array] container names to remove
    def rm(containers, opts={})
      execute("docker", "rm", *Array.wrap(containers), opts)
    end

    def run(opts={})
      raise(ArgumentError, "Need to supply an image: #{opts}") if opts[:image_name].to_s.blank?
      params = ParamList.new
      params.add_string_params([:name, :hostname, :entrypoint], opts)
      params.add_array_param('volumes-from', opts[:volumes_from])
      params.add_array_param('volume',       opts[:volumes])
      params.add_array_param('link',         opts[:links])
      params.add_array_param('publish',      opts[:ports])
      params.add_array_param('expose',       opts[:exposes])
      params.add_array_param('env',          opts[:envs])
      params.add_boolean(    'detach',       opts[:detach])
      params.add_array_param('attach',       opts[:attaches])
      params.add_flag(       '-it',          opts[:interactive])
      #
      params += opts[:other_params] if opts[:other_params].present?
      params << opts[:image_name]
      params += Array.wrap(opts[:entry_args])
      #
      execute('docker', 'run', *params, opts)
    end
  end

  class ParamList < Array
    def dasherize(name)
      name.to_s.gsub(/_/, '-')
    end
    def add_param(name, val)
      self << "--#{dasherize(name)}=#{val.to_s}" if val.present?
      self
    end
    def add_flag(str, val)
      self << str.to_s if val.present?
      self
    end
    def add_boolean(name, val)
      self << "--#{dasherize(name)}" if val.present?
      self
    end

    def add_string_params(names, opts)
      names.each{|name| add_param(name, opts[name.to_sym]) }
      self
    end
    def add_array_param(name, vals)
      Array.wrap(vals).each do |val|
        add_param(name, val)
      end
      self
    end
  end

end
