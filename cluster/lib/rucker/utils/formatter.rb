#
# Utility methods
#

module Rucker
  module_function

  #
  # Display to user
  #

  #
  # Don't do any colorization
  #
  class Formatter

    # @example
    #   colorize("This is ", :red, "crimson", " text")
    def colorize(*text)
      ctext = text.map do |el|
        el.is_a?(Symbol) ? color(el) : (el.to_s + off)
      end.join
      ctext << off()
    end
    
  end

  #
  # Use Terminal ANSI escapes to colorize text
  #
  class AnsiColorFormatter < Rucker::Formatter
    COLORS = {
      :blk => "\e[0;30m", :black   => "\e[0;30m",
      :red => "\e[0;31m",
      :grn => "\e[0;32m", :green   => "\e[0;32m",
      :ylw => "\e[0;33m", :yellow  => "\e[0;33m",
      :blu => "\e[0;34m", :blue    => "\e[0;34m",
      :pur => "\e[0;35m", :purple  => "\e[0;35m",
      :mag => "\e[0;35m", :magenta => "\e[0;35m",
      :cyn => "\e[0;36m", :cyan    => "\e[0;36m",
      :wht => "\e[0;37m", :white   => "\e[0;37m",

      :brk => "\e[1;30m", :br_black   => "\e[1;30m",
      :brr => "\e[1;31m",
      :brg => "\e[1;32m", :br_green   => "\e[1;32m",
      :bry => "\e[1;33m", :br_yellow  => "\e[1;33m",
      :brb => "\e[1;34m", :br_blue    => "\e[1;34m",
      :brp => "\e[1;35m", :br_purple  => "\e[1;35m",
      :brm => "\e[1;35m", :br_magenta => "\e[1;35m",
      :brc => "\e[1;36m", :br_cyan    => "\e[1;36m",
      :brw => "\e[1;37m", :br_white   => "\e[1;37m",

      :bld => "\e[1m",    :bold  => "\e[1m",
      :off => "\e[0m",
    }

    COLORS.each_pair do |tag, seq|
      define_method(tag) do |text|
        "#{seq}#{text}\e[0m"
      end
    end

    def off(text='')
      "\e[0m#{text}\e[0m"
    end

    def color(sym)
      COLORS[sym] || COLORS[:off]
    end    
  end

  #
  # Does not apply any colorization
  #
  class PlainFormatter < Rucker::Formatter
    Rucker::AnsiColorFormatter::COLORS.each_pair do |tag, esc|
      define_method(tag){|text| text }
    end
    def color(text)   ; '' ; end
    def off(text='')  ; text ; end 
  end
  
  def formatter=(val)
    @formatter = val
  end
  
  def formatter(val=nil)
    @formatter ||=
      begin 
        if    ENV['COLORIZE'] == 'true'   then Rucker::AnsiColorFormatter.new
        elsif ENV.has_key?('COLORIZE')    then Rucker::PlainFormatter.new
        elsif ENV['TERM'].to_s =~ /color/ then Rucker::AnsiColorFormatter.new
        else                                   Rucker::PlainFormatter.new
        end
      end
  end
  protected :formatter

  # Announce the headline of an important action
  def banner(*text, &blk)
    ctext = formatter.colorize(*text, &blk)
    #
    puts ""
    puts "  **************************************************"
    puts "  *"
    puts "  * " + ctext.gsub(/([\r\n]+)/, "\\1  *")
    puts "  *"
    puts     
  end

  # Announce an essential step in a process
  def progress(*text, &blk)
    puts formatter.colorize(*text, &blk)
  end

  # Deliver a block of text
  def output(*text, &blk)
    puts formatter.colorize(*text, &blk)
  end

  # Warn about a dangerous but not fatal condition
  def warn(*lines)
    Kernel.warn(*lines)
  end
end
