module Rucker

  def self.world
    @world ||= Rucker::Manifest::World.load(Pathname.of(:cluster_layout), 'local')
  end

  # Sorts repo_tag names in order by
  #
  # * slug, since equivalent slugs imply equivalent functions; then
  # * registry, because private registries are preferable to public; then
  # * tags starting with '_', so you can force an image to the head; then
  # * tagged 'latest', then by descending numeric part of tag if any, because
  #   software quality only increases over time;
  # * then tag name, to break ties,
  # * then repo, to break ties.
  #
  # This ordering is both visually pleasing and lets you call
  # `sort_by(...).first` for a good guess at the best available image to launch.
  #
  # @example img.repo_tags.sort_by{ Rucker.repo_tag_order(tag) }
  #   [
  #     "z.com/zzz/bar:_override",
  #     "a.com/yyy/bar",
  #     "a.com/yyy/bar:latest",
  #     "a.com/foo/bar:r9.0",
  #     "a.com/foo/bar:1.2",
  #     "b.com/aaa/bar:latest",
  #           "foo/bar:r10.1",
  #           "aaa/bar:r9.0",
  #           "foo/bar:r9.0",
  #           "zzz/bar:r9.0",
  #           "zzz/bar:r9.0-alpha",
  #           "zzz/bar:r9.0-beta",
  #           "foo/bar:r0.1",
  #     "a.com/foo/helper",
  #           "foo/helper",
  #     "a.com/foo/zazz", ]
  #
  def self.repo_tag_order(name)
    ph = Docker::Util.parse_reg_repo_tag(name)
    ordinary = 1
    case ph[:tag].to_s
    when /^_/             then num = - Float::INFINITY ; ordinary = -1
    when ''               then num = - Float::INFINITY
    when 'latest'         then num = - Float::INFINITY
    when /(\d+\.\d+|\d+)/ then num = - $1.to_f
    else                       num = 0
    end
    reg_str = ph[:reg].present? ? ph[:reg] : '||||||' # make private registries precede public
    [ ph[:slug].to_s, ordinary, reg_str.to_s, num, ph[:tag].to_s, ph[:repo].to_s ]
  end

  #
  # Config stuff, which lives too much everywhere.
  #
  
  def self.verbose=(val)
    @verbose = val
  end

  def verbose?
    return @verbose if instance_variable_defined?(:@verbose)
    ENV['VERBOSE'].present? && (ENV['VERBOSE'].to_s != 'false')
  end

  #
  # Assertions
  #

  def expect_one(name, arg)
    if arg.blank?
      Rucker.die "Please supply a single #{name} name by adding '#{name.upcase}=val' to the command line"
    elsif (arg.to_s == 'all')
      Rucker.die "Please supply a single #{name} name, not '#{name.upcase}=all'"
    end
    arg
  end

  def expect_some(name, arg)
    if arg.blank?
      Rucker.die "Please supply a single #{name} name with '#{name.upcase}=val', or '#{name.upcase}=all' for all relevant #{name}s"
    end
    arg
  end

  # When there is an **expected unexpected condition** -- e.g. we've been asked
  # to stop a container that doesn't exist -- the user shouldn't see a
  # backtrace, as the code wasn't at fault, the world is.
  #
  # This exits with an error, delivering your message without the carnage of a
  # backtrace.
  #
  # Going through here lets us decide later whether to raise an error (i.e. used
  # as a library) or abort (as now, used as a script, when a stack trace would
  # be silly), and gives us control over where the output is sent.
  #
  def die(*lines)
    first_line = lines.shift
    if first_line.is_a?(Exception) && Rucker.verbose?
      first_line = first_line.backtrace.reverse.join("\n") <<  "\n\n" << first_line.to_s
    end
    abort(['', first_line, *lines].join("\n"))
  end

  #
  # Extract output from Docker's reporting
  #

  HUMAN_TO_BYTES = { 'TB' => 2**40, 'GB' => 2**30, 'MB' => 2**20, 'kB' => 2**10, 'B' => 1 }
  def human_to_bytes(num, units)
    raise "Can't dehumanize #{[num, units].inspect}" if not HUMAN_TO_BYTES.include?(units)
    (num.to_f * HUMAN_TO_BYTES[units]).to_i
  end

  def bytes_to_human(size)
    return [] if size.blank?
    # since 1000-1024 waste 4 digits, and since most things are < 3 gb, roll units at 3072 not 1024
    HUMAN_TO_BYTES.each{|unit, mag| if size.abs > (3 * mag) then return [size.to_f / mag, unit] ; end }
    return [size, 'B']
  end
  def bytes_to_magnitude(size) bytes_to_human(size)[0] ; end
  def bytes_to_units(size)     bytes_to_human(size)[1] ; end

end

#
# Monkeypatching over a problem in current gorillb model
#

module Gorillib
  Model::ClassMethods.module_eval do
    def receive(attrs={}, &block)
      return nil if attrs.nil?
      return attrs if native?(attrs)
      #
      Gorillib::Model::Validate.hashlike!(attrs){ "attributes for #{self.inspect}" }
      type = attrs.delete(:_type) || attrs.delete('_type')
      klass = type.present? ? Gorillib::Factory(type) : self
      warn "factory #{klass} is not a subcass of #{self} (factory determined by _type: #{type.inspect} in #{attrs.inspect})" unless klass <= self
      #
      klass.new(attrs, &block)
    end
  end
  
  module AccessorFields
    extend Gorillib::Concern

    def handle_extra_attributes(attrs)
      accessor_fields.each do |fn|
        instance_variable_set(:"@#{fn}", attrs.delete(fn)) if attrs.include?(fn)
      end
      super
    end

    module ClassMethods
      def accessor_field(name, type=Whatever, opts={})
        opts = opts.reverse_merge(reader: :protected, writer: false)
        name = name.to_sym
        #
        attr_reader name if opts[:reader] 
        attr_writer name if opts[:writer]
        ivar_name = :"@#{name}"
        define_method(:"unset_#{name}"){ remove_instance_variable(ivar_name) if instance_variable_defined?(ivar_name) }
        #
        [ [name, opts[:reader]], ["#{name}=", opts[:writer]] ].each do |meth, visibility|
          case visibility
          when true       then protected(meth)
          when :protected then protected(meth)
          when :private   then private(meth)
          when :public    then public(meth)
          end
        end
        #
        self.accessor_fields += [name]
      end
    end

    self.included do |base|
      base.instance_eval do
        class_attribute :accessor_fields
        self.accessor_fields = []
      end
    end
    
  end
end
