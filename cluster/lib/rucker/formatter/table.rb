module Rucker
  class Formatter
    def self.htable(*args, &blk)
      Rucker::Formatter::HTable.new(*args, &blk)
    end

    class Table
      attr_reader   :formats
      attr_reader   :shows
      attr_accessor :trunc

      # We recognize
      #
      # * `s` -- string,  eg `%-23s` for a left-aligned string padded to 23 characters
      # * `d` -- integer, eg `%07d` for a right-aligned number zero-padded to seven characters
      # * `f` -- float,   eg `%7.2f`
      # * `a` -- array,   eg `%-23a` for a left-aligned dump of the array, padded to and truncated at 23 characters
      #
      FORMAT_RE = %r{\A % (-)?  (\d+) (?:\.(\d+))? ([asdf]) \z}x

      def initialize(spec, opts={})
        @formats = {}
        spec.each do |col, (spec, opts)|
          set_col_format(col, spec, opts)
        end
      end

      # Generate a header row, followed by one body row per object
      def table(objs, opts={})
        rows = []
        rows << header_row(opts)
        rows += objs.map{|obj| row(obj, opts) }
        rows
      end

      # Generate a row with the titles for each column
      def header_row(opts={})
        cols_to_show.map do |col|
          vv = str_spec(col) % title(col).to_s
          vv
        end.join("\t")
      end

      # Representation of the given object as a table row
      def row(obj, opts={})
        cols_to_show.map do |col|
          val = obj.send(col)
          arr?(col) ? arr_cell(col, val, opts) : val_cell(col, val, opts)
        end.join("\t")
      end

      # Generate a string representing the field's value
      def val_cell(col, val, opts)
        return (str_spec(col) % '') if val.nil?
        val = as(col).call(val) if as(col).present?
        spec(col) % val
      end

      def truncate(str, len, opts={})
        dotdotdot = '...'
        return str if (opts[:full]) || (str.length <= len)
        str[ 0 .. (len - dotdotdot.length - 1) ] + dotdotdot
      end

      # Generate the single string representing an array field
      # If an `as` block is given, it's applied to each element in turn.
      def arr_cell(col, arr, opts)
        arr = arr.map{|val| as(col).call(val) } if as(col).present?
        str = arr.join(',')
        str = truncate(str, len(col), opts)
        str_spec(col) % str
      end

      # Describe the format for the named column
      def set_col_format(col, spec, opts={})
        spec =~ FORMAT_RE or (warn "Weird format #{spec}" ; return { spec: spec })
        @formats[col] = { spec: spec, show: true, title: col.to_s.titleize,
          left: $1.to_s, len: $2.to_i, prec: $3.to_i, type: $4.to_s }.merge(opts)
      end

      # The expected width of the column in characters
      def len(col)      formats[col][:len] ; end
      # The printf-style `%` specifier for how to print each value
      def spec(col)     formats[col][:spec] ; end
      # True to left justify (padding comes after value)
      def left(col)     formats[col][:left] ; end
      # True if the column should be displayed
      def show?(col) !! formats[col][:show] ; end
      # Is it an array value (using the ersatz '%a' format)
      def arr?(col)     formats[col][:type] == 'a' ; end
      # The title to present. Otherwise we'll titleize the field name:
      # `:ip_address` becomes 'Ip Address', `foo_id` becomes 'foo'.
      def title(col)    formats[col][:title] ; end

      # A block called to prepare the cell values when `#to_s` won't do
      # @example
      #   created_at:  [ '%-15s', { as: ->(tm){ tm.iso8601 } }]
      def as(col)       formats[col][:as] ; end

      # the specification for printing a string in place of the normal value.
      # For example, a `%7.2f` float would give a string spec of `%-7s`
      def str_spec(col)
        ['%-', len(col), 's'].join
      end

      def cols_to_show
        formats.keys.select{|col| show?(col) }
      end
    end


    class HTable
      def initialize(head_lines, &blk)
        head(*head_lines)
        draw(&blk) if block_given?
      end

      def head(*text)
        Rucker.output :brg, *text
      end

      def row(title, *text)
        first = text.shift
        Rucker.output(:blu, ("  %-21s" % title.to_s), :bold, "\t#{first}", *text)
      end

      def draw(&blk)
        yield(self) if block_given?
      end
    end

  end

  module Manifest

    Container.class_eval do
      def self.table_fields
        {
          name:            [ '%-20s', {}  ],
          state:           [ '%-7s',  {}  ],
          ip_address:      [ '%-14s', {}  ],
          hostname:        [ '%-15s', {}  ],
          image_name:      [ '%-31s', {}  ],
          image_id:        [ '%-13s', {}  ],
          created_at:      [ '%-15s', { as: ->(tm){ tm.to_s.gsub(/[-:Z]|\..*/,'').gsub(/T/, '-') } }],
          started_at:      [ '%-15s', { as: ->(tm){ tm.to_s.gsub(/[-:Z]|\..*/,'').gsub(/T/, '-') } }],
          stopped_at:      [ '%-15s', { as: ->(tm){ tm.to_s.gsub(/[-:Z]|\..*/,'').gsub(/T/, '-') } }],
          exit_code:       [ '%4s',   { title: 'Exit' }  ],
          links:           [ '%-39a', { as: ->(lk){ lk.gsub(/:.*/,'') } }],
          volumes:         [ '%-31a', { show: false } ],
          volumes_from:    [ '%-23a', {}  ],
          published_ports: [ '%-31a', { as: ->(port){ port.cport_hport } }],
          ports:           [ '%-31a', { show: false} ],
        }
      end
      def self.table_formatter
        Rucker::Formatter::Table.new(table_fields)
      end
    end

    #     PRINTF_FORMAT = %w[%-15s %-15s %-7s %14d %7.1f\ %2s %10s %-23s %-31s %s].join("\t")
    #     HEADER_FORMAT = %w[%-15s %-15s %-7s %14s   %7s\ %2s %10s %-23s %-31s %s].join("\t") %
    #       %w[namespace  slug  tag  size  human \  short_id ago name short_cmd]
    #
    #     def to_table
    #       PRINTF_FORMAT % [ns, slug, tag, size, sz_mag, sz_units, short_id, ago, name, short_cmd]
    #     end

    Image.class_eval do
      def self.table_fields
        {
          registry:      [ '%-15s', {}  ],
          repo:          [ '%-15s', {}  ],
          slug:          [ '%-15s', {}  ],
          tag:           [ '%-7s',  {}  ],
          readable_size: [ '%7s',   { title: 'Size' }  ],
          size:          [ '%13d',  {}  ],
          short_id:      [ '%10s',  { title: 'ID' }  ],
          name:          [ '%-31s', {}  ],
          created_at:    [ '%-15s', { as: ->(tm){ tm.to_s.gsub(/[-:Z]|\..*/,'').gsub(/T/, '-') } }],
        }
      end
      def self.table_formatter
        Rucker::Formatter::Table.new(table_fields)
      end
    end

    World.class_eval do
      def dump_info
        Rucker::Formatter.htable("World #{name}:") do |tbl|
          tbl.row 'State:', state_desc
          clusters.each do |cl|
            tbl.row cl.desc, cl.state_desc
          end
          tbl.row 'Defined containers:', containers.size
          tbl.row 'Defined images:',     images.size
        end
      end
    end

    # module Actual
    #
    #   Image.class_eval do
    #
    #     PRINTF_FORMAT = %w[%-15s %-15s %-7s %14d %7.1f\ %2s %10s %-23s %-31s %s].join("\t")
    #     HEADER_FORMAT = %w[%-15s %-15s %-7s %14s   %7s\ %2s %10s %-23s %-31s %s].join("\t") %
    #       %w[namespace  slug  tag  size  human \  short_id ago name short_cmd]
    #
    #     def to_table
    #       PRINTF_FORMAT % [ns, slug, tag, size, sz_mag, sz_units, short_id, ago, name, short_cmd]
    #     end
    #     def self.table_headers
    #       HEADER_FORMAT
    #     end
    #
    #     def self.images_table(images)
    #       lines  = [table_headers]
    #       lines += images.to_a.sort_by(&:comparable_name).map{|image| image.to_table }
    #       lines
    #     end
    #
    #     # feae5a29ea12        About an hour ago   /bin/sh -c #(nop) COPY file:bb5fb02a76c6852b8   2.091 kB
    #     HISTORY_RE = /^([0-9a-f]+)\s+(.*?ago)\s+(.*?)\s+([0-9\.]+) (B|kB|MB|GB)$/
    #     # bd4c/baseimage       latest              db0ad19d8544        58 seconds ago      713.7 MB
    #     LISTING_RE = /^([\w\/\-<>]+)\s+([\w\/\-\.<>]+)\s+([0-9a-f]+)\s+(.*?ago)\s+([0-9\.]+) (B|kB|MB|GB)$/
    #
    #     # name, tag, image id, created, virtual size
    #     def self.from_listing(str)
    #       name, tag, id, ago, sz_num, sz_units = str.chomp.match(LISTING_RE).captures rescue nil
    #       unless sz_units then warn "Bad match: #{str} vs #{LISTING_RE}" ; return ; end
    #       size = Rucker.human_to_bytes(sz_num, gsz_units)
    #       new(id, "#{name}:#{tag}", size, ago, '')
    #     end
    #
    #     # image, created, command, size
    #     def self.from_history(name, str)
    #       id, ago, cmd, sz_num, sz_units = str.chomp.match(HISTORY_RE).captures rescue nil
    #       return unless sz_units
    #       size = Rucker.human_to_bytes(sz_num, sz_units)
    #       new(id, name, size, ago, cmd)
    #     end
    #
    #     def self.dump_history(img_name)
    #       img_name += ':latest' if not (img_name =~ /:\w+\z/)
    #       output, stderr, status  = Rucker::Runner.get_output('docker', 'history', '--no-trunc', img_name)
    #       lines = output.split(/[\r\n]+/).drop(1)
    #       images = lines.reverse.map{|line| self.from_history(img_name, line) }
    #       puts images_table(images)
    #     end
    #
    #     def self.dump_images(img_names)
    #       output, stderr, status  = Rucker::Runner.get_output('docker', 'images', '--no-trunc', img_names, ignore_errors: true)
    #       lines = output.split(/[\r\n]+/).drop(1)
    #       images = lines.map{|line| self.from_listing(line) }
    #       puts images_table(images)
    #     end
    #
    #   end
    #
    # end

  end

  module Actual

    # def dump_docker_envvars
    #
    # end
    class DockerServer
      include Gorillib::AccessorFields

      accessor_field :docker_info
      accessor_field :version_info

      def docker_info
        @docker_info ||= Docker.info
      end
      def version_info
        @version_info ||= Docker.version
      end
      def forget()
        unset_docker_info
        unset_version_info
      end
      def url
        Docker.url
      end
      def cert_path
        ENV['DOCKER_CERT_PATH']
      end
      def socketed?
        url =~ %r{^unix:}
      end
      def use_https?
        (ENV['DOCKER_TLS_VERIFY'].to_i == 1)
      end
      def has_certs?
      end

      # @return [Integer] Total number of containers, running and stopped
      def num_ctr()     docker_info['Containers'] ; end

      # @return [Integer] the total number of unique image build layers
      def num_img_layers() docker_info['Images'] ; end

      # @return [true, false] Is IPv4 port forwarding enabled?
      def forwarding?() docker_info['IPv4Forwarding'].to_i == 1 ; end

      # @return [String] Registry to pull images from
      def registry()    docker_info['IndexServerAddress'] ; end

      # @return [String] Path where containers are provisioned
      def root_vol()    docker_info['DriverStatus'][0][1] rescue docker_info['DriverStatus'] ; end

      # @return [String] The API version provided by the docker host
      def docker_api_version() version_info['ApiVersion'] ; end

      # @return [String] The version of docker itself
      def docker_version() version_info['Version'] ; end

      def docker_addr_str
        case
        when url =~ %r{tcp://([^:]+)}    then $1
        when ENV['DOCKER_ADDR'].present? then ENV['DOCKER_ADDR']
        when socketed?                   then "localhost\t(?maybe?)"
        else                                  '(unknown)'
        end
      end

      def dump_info
        lint!
        #
        Rucker::Formatter.htable("Global info for #{url}") do |tbl|
          #
          tbl.row 'Docker Address:',     docker_addr_str
          tbl.row 'Use HTTPS:',          use_https?
          tbl.row '$DOCKER_HOST',        printable_env('DOCKER_HOST')
          tbl.row '$DOCKER_TLS_VERIFY',  printable_env('DOCKER_TLS_VERIFY')
          tbl.row '$DOCKER_CERT_PATH',   printable_env('DOCKER_CERT_PATH')
          tbl.row 'Docker Version:',     docker_version
          tbl.row 'Docker API Version:', docker_api_version
          tbl.row 'Registry:',           registry
          tbl.row 'Port Forwarding?',    forwarding?
          tbl.row 'Containers:',         num_ctr
          tbl.row 'Image Layers:',       num_img_layers
          if Rucker.verbose?
            tbl.row 'Complete dump:', '', :norm, docker_info.merge(version_info)
          end
        end
      rescue StandardError => err
        Rucker.die(err,
          "Problems fetching info about the docker host: '#{err.message}'. Check that it is running, and that your DOCKER_HOST, DOCKER_CERT_PATH and DOCKER_TLS_VERIFY environment variables are correct." )
      end

      def printable_env(name)
        val = ENV[name]
        case
        when val.nil?                 then return '(unset)'
        when val.blank?               then return val.inspect
        when val.respond_to?(:to_str) then return val.to_str
        else                               return val.inspect
        end
      end

      def lint!
        errors = []
        #
        errors << "$DOCKER_TLS_VERIFY should be unset, 1 or 0: #{ENV['DOCKER_TLS_VERIFY']}" unless [nil, '1', '0'].include?(ENV['DOCKER_TLS_VERIFY'])
        errors << "$DOCKER_CERT_PATH is set but empty -- unset it or fill in a good value" if (cert_path == '')
        #
        if use_https?
          errors << "Cannot use HTTPS (as set by DOCKER_TLS_VERIFY) with a direct socket connection" if socketed?
          errors << "$DOCKER_CERT_PATH is unset, but DOCKER_TLS_VERIFY" if cert_path.nil?
          %w[ca.pem  cert.pem  key.pem].each do |fn|
            cert_fn = File.join(ENV['DOCKER_CERT_PATH'], fn)
            errors << "Certificate file #{cert_fn} missing" if not File.exists?(cert_fn)
          end
        else
          errors << "Don't set DOCKER_CERT_PATH if DOCKER_TLS_VERIFY is off" if not cert_path.nil?
        end
        if errors.present?
          Rucker.warn("Problems in connection configuration:", *errors.map{|msg| "  Warning: #{msg}" })
        end
        errors.empty?
      end

    end
  end

end
