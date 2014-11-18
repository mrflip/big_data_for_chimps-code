module Rucker

  module Runner
    module_function

    def execute(*args)
      opts = args.extract_options!
      args.map!(&:to_s)
      Rake.sh(*args) do |ok, res|
        if (not ok) && (not opts[:ignore_errors])
          abort("Command #{args.join(' ')} exited unsuccessfully (#{res.exitstatus})")
        end
      end
    end

    def get_output(*args)
      opts = args.extract_options!
      args.map!(&:to_s)
      require 'childprocess'
      out, err, status = Gorillib::System::Runner.run(args)
      if (status != 0) && (not opts[:ignore_errors])
        $stdout.write out
        $stderr.write err
        abort("Command #{args.join(' ')} exited unsuccessfully (#{status}).")
      end
      [out, err, status]
    end

  end

  class ImageRunner

    # # From https://github.com/swipely/docker-api/blob/master/lib/docker/util.rb
    # # Modified to add the
    # def create_dir_tar(directory)
    #   cwd = FileUtils.pwd
    #   tempfile_name = Dir::Tmpname.create('out') {}
    #   tempfile = File.open(tempfile_name, 'wb+')
    #   FileUtils.cd(directory)
    #   Archive::Tar::Minitar.pack('.', tempfile)
    #   File.new(tempfile.path, 'r')
    # ensure
    #   FileUtils.cd(cwd)
    # end
  end

  module ContainerRunner
    extend Runner
    module_function

    # Start the given container
    # @param container [Rucker::Container] the container to start
    def start(container, opts={})
      params = ParamList.new.add_flag('-ia', opts[:interactive])
      execute(*["docker", "start", *params, container.name], opts)
    end

    # Stop the named containers
    # @param names [Array] container names to remove
    def stop(names, opts={})
      execute(*["docker", "stop", *Array.wrap(names)], opts)
    end

    # Remove the named containers
    # @param names [Array] container names to remove
    def rm(names, opts={})
      execute("docker", "rm", '-v', *Array.wrap(names), opts)
    end

    def diff(name, opts={})
      execute("docker", "diff", name, opts)
    end

    def commit(ctr_name, img_name, opts={})
      execute('docker', 'commit', ctr_name, img_name)
    end

    def docker_info(names, opts={})
      output, stderr, status = get_output('docker', 'inspect', *Array.wrap(names), ignore_errors: true)
      MultiJson.load(output, symbolize_keys: true) rescue [Hash.new]
    end

    def docker_inspect(names, opts={})
      execute('docker', 'inspect', *Array.wrap(names))
    end

    # @param container [Rucker::Container] The container to run.
    # @param opts [Hash] Options override container attributes.
    def run(container, opts={})
      opts = container.attributes.merge(opts)
      #
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
