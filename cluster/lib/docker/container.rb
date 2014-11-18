module Docker
  #
  # We're breaking the promise of caching nothing on the justification that we
  # are executing high-level care in the orchestration level.
  #
  Container.class_eval do

    # Remove memoized last-seen info so that future calls will force a fetch
    def forget
      remove_instance_variable :@ext_info
      return self
    end

    #
    # These things come back for free with the call to .all
    #

    def simple_container_hsh
      {
        names:       names,
        id:          id,
        created_at:  created_at,
        command_str: command_str,
        image_name:  image_name,
        status_str:  status_str,
        ports:       ports,
      }.merge(parse_status_str(status_str))
    end

    STATUS_STR_RE = %r{(?: (Up|\s  )}x
    def parse_status_str(str)
      case str
      when %r{\AExited \((\d+)\) (.*)\z} then { state: :stopped, ago_str: $2, exit_code: $1.to_i}
      when %r{\AUp (.*?) \(Paused\)\z}   then { state: :paused,  ago_str: $1 }
      when %r{\AUp (.*)\z}               then { state: :running, ago_str: $1 }
      when %r{restart ?(.*)}i            then { state: :restart, ago_str: $1 } # don't know what this looks like
    end

    def names()           @info['Names']   ; end
    def image_name()      @info['Image']   ; end
    def command()         @info['Command'] ; end
    def created_at()      @info['Created'] ; end
    def status_str()      @info['Status']  ; end
    # "SizeRw":12288,
    # "SizeRootFs":0

    FIXUP_NAME_RE = %r{^/}
    def names()
      info['Names'].map{|name| name.gsub(FIXUP_NAME_RE, '').to_sym }
    end

    def ports()
      info['Ports'].map do |port_hsh|
        { bind: port_hsh["IP"], hport: port_hsh['PrivatePort'], cport: port_hsh['PublicPort'], proto: port_hsh['Type'] }
      end
    end

    #
    # These require an extra call to get the detailed info
    #

    # Memoized request for detailed values
    def ext_info
      @ext_info  ||= json
    end

    def container_hsh
      simple_container_hsh.merge(
        links:         links
        started_at:    started_at,
        finished_at:   finished_at,
        ip_address:    ip_address,
        image_id:      image_id,
        volumes:       all_volumes,
        volumes_from:  volumes_from,
        state:         state,
      )
    end

    FIXUP_LINK_NAME_RE = %r{^.*/(.*?):.*}
    def links
      links = ext_info['HostConfig']['Links'] or return Array.new
      links.map{|link| link.gsub(FIXUP_LINK_NAME_RE, '\1') }
    end
    #
    def ip_address()      ext_info['NetworkSettings']['IPAddress'] ;  end
    def image_id()        ext_info['Image']               ; end

    # As requested at config time

    def conf_image_name() ext_info['Config']['Image'] ; end
    def conf_volumes()    ext_info['Config']['Volumes'].keys   || Array.new rescue Array.new ; end
    def volumes_from()    ext_info['HostConfig']['VolumesFrom'] || Array.new ; end

    # Volume status
    def all_volumes()
      ext_info['Volumes'].map do |name, path|
        writeable = ext_info["VolumesRW"][name]
        { name: name, path: path, writeable: writeable }
      end
    end

    def exit_code()       ext_info['State']['ExitCode']   ; end
    def started_at        ext_info['State']['StartedAt']  ; end
    def finished_at       ext_info['State']['FinishedAt'] ; end
    # also: ghost, pid
    #
    def state()
      state_hsh = ext_info['State']
      case
      when state_hsh['Running']    then :running
      when state_hsh['Restarting'] then :restart
      when state_hsh['Paused']     then :paused
      else                              :stopped
      end
    end
  end
end
