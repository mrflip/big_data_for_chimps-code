module Rucker
  class Formatter

    class Table
      attr_reader   :formats
      attr_reader   :shows
      attr_accessor :trunc

      FORMAT_RE = %r{\A % (-)?  (\d+) (?:\.(\d+))? ([asdf]) \z}x

      def initialize(spec, opts={})
        @formats = {}
        spec.each do |col, (fmt, opts)|
          set_col_format(col, fmt, opts)
        end
      end

      def table(objs, opts={})
        rows = []
        rows << header_row(opts)
        rows += objs.map{|obj| row(obj, opts) }
        rows
      end

      def header_row(opts={})
        show_cols.map do |col|
          vv = str_fmt(col) % col.to_s.titleize
          vv
        end.join("\t")
      end

      def row(obj, opts={})
        show_cols.map do |col|
          val = obj.send(col)
          arr?(col) ? arr_cell(col, val, opts) : val_cell(col, val, opts)
        end.join("\t")
      end

      def val_cell(col, val, opts)
        val = as(col).call(val) if as(col).present?
        fmt(col) % val
      end

      def arr_cell(col, arr, opts)
        arr = arr.map{|val| as(col).call(val) } if as(col).present?
        str = arr.join(',')
        if (not opts[:full]) && (str.length > len(col))
          str = str[0..(len(col)-4)]+'...'
        end
        str_fmt(col) % str
      end

      def set_col_format(col, fmt, opts={})
        fmt =~ FORMAT_RE or (warn "Weird format #{fmt}" ; return { fmt: fmt })
        @formats[col] = { fmt: fmt, show: true,
          left: $1.to_s, len: $2.to_i, prec: $3.to_i, type: $4.to_s }.merge(opts)
      end

      def len(col)      formats[col][:len] ; end
      def fmt(col)      formats[col][:fmt] ; end
      def left(col)     formats[col][:left] ; end
      def show?(col) !! formats[col][:show] ; end
      def arr?(col)     formats[col][:type] == 'a' ; end

      def as(col)       formats[col][:as] ; end

      def str_fmt(col)
        ['%', left(col), len(col), 's'].join
      end

      def show_cols
        formats.keys.select{|col| show?(col) }
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

    # World.class_eval do
    #   def dump_info(names, flds)
    #     ctrs = docker_info(names)
    #     puts Rucker::Container.dump_header(*flds)
    #     ctrs.each do |ctr|
    #       puts ctr.dump(*flds)
    #     end
    #     clusters.each{|cl| puts "#{cl.type_name} #{cl.name} is #{cl.state_desc}" }
    #     puts "#{type_name} #{name} is #{state_desc}"
    #     self
    #   end
    # end

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
    #       size = Rucker.human_to_bytes(sz_num, sz_units)
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
end
