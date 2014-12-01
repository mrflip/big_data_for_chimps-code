module Configliere

  # def self.use(*mixins)
  #   raise ArgumentError, "Please provide a mixin to use" if mixins.empty?
  #   mixins.each do |mixin|
  #     require "configliere/#{mixin}"
  #     mod_name = "/#{mixin}".gsub(/\/(.?)/){ "::#{ $1.upcase }" }.gsub(/(?:^|_)(.)/){ $1.upcase }
  #     Configliere::Param.extend(Object.module_eval(mod_name, __FILE__, __LINE__))
  #   end
  # end

  require 'configliere/commandline'
  Param.class_eval do

    def parse_argv!
      resolve!(false)
      ARGV.reject! do |arg|
        break if arg == '--'
        arg =~ /\A-/
      end
      self
    end

  end
end
