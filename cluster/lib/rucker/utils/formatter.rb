module Rucker
  module_function

  #
  # Display to user
  #

  def formatter=(val)
    @formatter = val
  end

  def formatter(val=nil)
    @formatter ||= (use_color? ? Rucker::AnsiColorFormatter.new : Rucker::PlainFormatter.new)
  end
  protected :formatter

  # Announce the headline of an important action
  def banner(*text, &blk)
    ctext = formatter.format(*text, &blk)
    #
    puts ""
    puts "  **************************************************"
    puts "  *"
    puts "  * " + ctext.gsub(/([\r\n]+)/, "\\1  *")
    puts "  *"
    puts
  end

  MOODS = {
    # creation
    adding:   :brg, creating: :brg, pulling:   :brg, sending:     :brg,
    # change
    updating: :brb, tagging:  :brb, pushing:   :brb, downloading: :brb,
    starting: :brb, unpausing: :brb, authing:  :brb,
    # destruction
    stopping: :red, pausing:   :red,
    removing: :brr,
    # self
    as:       :cya, for:      :cya,
    # other
    with:     :mag, to:       :mag, from: :mag,
    # alertness
    note:     :red, danger:   :brr, error: :brr, success: :brg,
  }
  # completed actions represent mild change
  %w[added created pulled pushed tagged removed
     stopped started paused unpaused sent downloaded
     ].each{|mood| MOODS[mood.to_sym] = :blu }

  # Announce an essential step in a process
  def progress(action, subj, opts={})
    opts      = opts.reverse_merge(indent: 1)
    indent    = opts.delete(:indent)
    skipped   = opts.delete(:skipped)
    error     = opts[:error]
    subj_desc = (subj.respond_to?(:desc) ? subj.desc : subj)
    #
    return if (not error) && (opts.include?(:mute)) && (rand > opts.delete(:mute).to_f)
    #
    mood      = MOODS[action.to_sym] || :normal
    mood      = :normal        if skipped.present?
    mood      = MOODS[:error]  if error.present?
    action_str = ("  "*indent)
    action_str << "not " if (skipped || error)
    action_str << action.to_s.humanize
    #
    text = []
    text << mood << ("%-15s" % action_str) << ' '
    text << :cya << ("%-30s" % subj_desc)
    #
    opts.each do |phrase, words|
      text << ' ' << phrase.to_s << ' '
      text << MOODS[phrase] if MOODS.include?(phrase)
      text << words
    end
    text << " (Skipped because #{skipped})" if skipped
    #
    text = text.flatten
    output(*text)
  end

  # Deliver a block of text
  def output(*text, &blk)
    puts formatter.format(*text, &blk)
  end

  # Warn about a dangerous but not fatal condition
  def warn(*lines)
    Kernel.warn(*lines)
  end

  #
  # Don't do any colorization
  #
  class Formatter
    def is_style?(el)
      el.is_a?(Symbol) && COLORS.include?(el)
    end

    # @example
    #   format("This is ", :red, "crimson", " text")
    def format(*texts)
      out = []
      while texts.present?
        el = texts.shift
        if is_style?(el)
          out << self.public_send(el, texts.shift)
        else
          out << normal(el.to_s)
        end
      end
      out.join
    end

    COLORS = {
      :black      => ["\e[0;30m",   [  0,  0,    0],  ],
      :red        => ["\e[0;31m",   [147, 17,   26],  ],
      :green      => ["\e[0;32m",   [133, 153,   0],  ],
      :yellow     => ["\e[0;33m",   [181, 137,   0],  ],
      :blue       => ["\e[0;34m",   [ 33,  76, 147],  ],
      :magenta    => ["\e[0;35m",   [145, 97,  175],  ],
      :cyan       => ["\e[0;36m",   [ 42, 161, 152],  ],
      :white      => ["\e[0;37m",   [238, 232, 213],  ],
      #
      :br_black   => ["\e[1;30m",   [ 88, 110, 117],  ],
      :br_red     => ["\e[1;31m",   [220,  50,  47],  ],
      :br_green   => ["\e[1;32m",   [ 36, 142,  34],  ],
      :br_yellow  => ["\e[1;33m",   [186, 193,  22],  ],
      :br_blue    => ["\e[1;34m",   [ 38, 139, 210],  ],
      :br_magenta => ["\e[1;35m",   [211,  54, 130],  ],
      :br_cyan    => ["\e[1;36m",   [ 49, 192, 181],  ],
      :br_white   => ["\e[1;37m",   [253, 246, 227],  ],
      #
      :bold       => ["\e[1m",	    ],
      :normal     => ["\e[0m",	    ],
    }
    {
      :blk => :black,                            :grn => :green,      :ylw => :yellow,
      :blu => :blue,        :mag => :magenta,    :cyn => :cyan,       :wht => :white,
      :brk => :br_black,    :brr => :br_red,     :brg => :br_green,   :bry => :br_yellow,
      :brb => :br_blue,     :brm => :br_magenta, :brc => :br_cyan,    :brw => :br_white,
      :pur => :magenta,     :purple => :magenta, :brp => :br_magenta,  :br_purple => :br_magenta,
      :cya => :cyan,
      :bld => :bold,        :off => :normal,     :norm => :normal,
    }.each{|shortname, name| COLORS[shortname] = COLORS[name] }
  end

  # If the $COLORIZE environment variable is set to true or false, colors will
  # always (true) or never (false) be used.
  #
  # Otherwise, color is enabled only if both of the following are true:
  #
  # * the output is a tty (i.e. not piped into a file or another process)
  # * the terminal setting (`$TERM`) has the word 'color' in it
  #
  def use_color?
    return false if (ENV['COLORIZE'].to_s == 'false')
    return true  if (ENV['COLORIZE'].to_s == 'true')
    return false if not $stdout.isatty
    return true  if (ENV['TERM'].to_s =~ /color/)
    false
  end

  #
  # Does not apply any colorization
  #
  class PlainFormatter < Rucker::Formatter
    COLORS.each_pair do |tag, (ansi, rgb)|
      define_method(tag){|text| text }
    end
    def off(text='')  ; text ; end
  end

  #
  # Use Terminal ANSI escapes to colorize text
  #
  class AnsiColorFormatter < Rucker::Formatter
    COLORS.each_pair do |tag, (ansi, rgb)|
      define_method(tag) do |text|
        "#{ansi}#{text}\e[0m"
      end
    end

    def off(text='')
      "\e[0m#{text}\e[0m"
    end
    def normal(text='')
      off(text)
    end
  end

  # Proof of concept, walk on by...
  #
  # class HtmlFormatter < Rucker::Formatter
  #   Rucker::Formatter::COLORS.each_pair do |tag, (ansi, rgb)|
  #     define_method(tag){|text| "<span class=\"#{tag}\">#{text}</span>" }
  #   end
  #
  #   def bold(text)
  #     '<strong>' << text << '</strong>'
  #   end
  #
  #   def head(*text)
  #     out = ['<tr>']
  #     text.each{|tt| out << '<th>' << tt << '</th>' }
  #     out << '</tr>'
  #     out.flatten.join
  #   end
  #
  #   def hrow(title, *text)
  #     out = ['<tr>']
  #     out << '<th>' << title << '</th>'
  #     text.each{|tt| out << '<td><code>' << tt << '</code></td>' }
  #     out << '</tr>'
  #     out.flatten.join
  #   end
  #
  #   def row(*text)
  #     out = ['<tr>']
  #     text.each{|tt| out << '<td>' << tt << '</td>' }
  #     out << '</tr>'
  #     out.flatten.join
  #   end
  # end
end
