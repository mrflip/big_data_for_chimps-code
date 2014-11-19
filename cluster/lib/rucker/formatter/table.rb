module Rucker
  Container.class_eval do
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
      str << "\t%-12s" % image_id                              if flds.include?(:image_id)
      str << "\t%-64s" % full_image_id                         if flds.include?(:full_image_id)
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
  end

  World.class_eval do

    def dump_info(names, flds)
      ctrs = docker_info(names)
      puts Rucker::Container.dump_header(*flds)
      ctrs.each do |ctr|
        puts ctr.dump(*flds)
      end
      clusters.each{|cl| puts "#{cl.type_name} #{cl.name} is #{cl.state_desc}" }
      puts "#{type_name} #{name} is #{state_desc}"
      self
    end

  end

  module Actual

    Image.class_eval do

      PRINTF_FORMAT = %w[%-15s %-15s %-7s %14d %7.1f\ %2s %10s %-23s %-31s %s].join("\t")
      HEADER_FORMAT = %w[%-15s %-15s %-7s %14s   %7s\ %2s %10s %-23s %-31s %s].join("\t") %
        %w[namespace  slug  tag  size  human \  short_id ago name short_cmd]

      def to_table
        PRINTF_FORMAT % [ns, slug, tag, size, sz_mag, sz_units, short_id, ago, name, short_cmd]
      end
      def self.table_headers
        HEADER_FORMAT
      end

      def self.images_table(images)
        lines  = [table_headers]
        lines += images.to_a.sort_by(&:comparable_name).map{|image| image.to_table }
        lines
      end

      # feae5a29ea12        About an hour ago   /bin/sh -c #(nop) COPY file:bb5fb02a76c6852b8   2.091 kB
      HISTORY_RE = /^([0-9a-f]+)\s+(.*?ago)\s+(.*?)\s+([0-9\.]+) (B|kB|MB|GB)$/
      # bd4c/baseimage       latest              db0ad19d8544        58 seconds ago      713.7 MB
      LISTING_RE = /^([\w\/\-<>]+)\s+([\w\/\-\.<>]+)\s+([0-9a-f]+)\s+(.*?ago)\s+([0-9\.]+) (B|kB|MB|GB)$/

      # name, tag, image id, created, virtual size
      def self.from_listing(str)
        name, tag, id, ago, sz_num, sz_units = str.chomp.match(LISTING_RE).captures rescue nil
        unless sz_units then warn "Bad match: #{str} vs #{LISTING_RE}" ; return ; end
        size = Rucker.human_to_bytes(sz_num, sz_units)
        new(id, "#{name}:#{tag}", size, ago, '')
      end

      # image, created, command, size
      def self.from_history(name, str)
        id, ago, cmd, sz_num, sz_units = str.chomp.match(HISTORY_RE).captures rescue nil
        return unless sz_units
        size = Rucker.human_to_bytes(sz_num, sz_units)
        new(id, name, size, ago, cmd)
      end

      def self.dump_history(img_name)
        img_name += ':latest' if not (img_name =~ /:\w+\z/)
        output, stderr, status  = Rucker::Runner.get_output('docker', 'history', '--no-trunc', img_name)
        lines = output.split(/[\r\n]+/).drop(1)
        images = lines.reverse.map{|line| self.from_history(img_name, line) }
        puts images_table(images)
      end

      def self.dump_images(img_names)
        output, stderr, status  = Rucker::Runner.get_output('docker', 'images', '--no-trunc', img_names, ignore_errors: true)
        lines = output.split(/[\r\n]+/).drop(1)
        images = lines.map{|line| self.from_listing(line) }
        puts images_table(images)
      end

    end

  end
end
