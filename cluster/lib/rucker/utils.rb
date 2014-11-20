#
# Utility methods
#

module Rucker
  extend self

  HUMAN_TO_BYTES = { 'TB' => 2**40, 'GB' => 2**30, 'MB' => 2**20, 'kB' => 2**10, 'B' => 1 }
  def human_to_bytes(num, units)
    raise "Can't dehumanize #{[num, units].inspect}" if not HUMAN_TO_BYTES.include?(units)
    (num.to_f * HUMAN_TO_BYTES[units]).to_i
  end

  def bytes_to_human(size)
    # since 1000-1024 waste 4 digits, and since most things are < 3 gb, roll units at 3072 not 1024
    HUMAN_TO_BYTES.each{|unit, mag| if size.abs > (3 * mag) then return [size.to_f / mag, unit] ; end }
    return [size, 'B']
  end
  def bytes_to_magnitude(size) bytes_to_human(size)[0] ; end
  def bytes_to_units(size)     bytes_to_human(size)[1] ; end

  def banner(str)
    puts( "\n  " + "*"*50 + "\n  *\n" )
    puts "  * #{str}\n  *\n"
  end

  def expect_one(name, arg)
    if arg.blank?
      abort "Please supply a single #{name} name by adding '#{name.upcase}=val' to the command line"
    elsif (arg.to_s == 'all')
      abort "Please supply a single #{name} name, not '#{name.upcase}=all'"
    end
    arg
  end

  def expect_some(name, arg)
    if arg.blank?
      abort "Please supply a single #{name} name with '#{name.upcase}=val', or '#{name.upcase}=all' for all relevant #{name}s"
    end
    arg
  end


  # Going through here lets us decide later whether to raise an error (i.e. used
  # as a library) or abort (as now, used as a script, when a stack trace would
  # be silly)
  def die(msg)
    msg += caller[0..1].join(" // ")
    abort(msg)
  end
end

#
# Monkeypatching over a problem in current gorillb model
#

Gorillib::Model::ClassMethods.module_eval do
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
