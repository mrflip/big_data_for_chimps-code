require 'pry'
require 'yaml'
require 'rake'
require 'rake/file_utils.rb'
require 'multi_json'

require 'gorillib'
require 'gorillib/pathname'
require 'gorillib/hash/keys'
require 'gorillib/array/wrap'
require 'gorillib/enumerable/hashify'
require 'gorillib/system/runner'

require 'gorillib/object/blank'
require 'gorillib/object/try'
require 'gorillib/object/try_dup'
require 'gorillib/array/extract_options'
require 'gorillib/hash/keys'
require 'gorillib/hash/slice'
require 'gorillib/string/inflector'
require 'gorillib/exception/raisers'
require 'gorillib/metaprogramming/concern'
require 'gorillib/metaprogramming/class_attribute'
#
require 'gorillib/factories'
# require 'gorillib/type/extended'
require 'gorillib/model/named_schema'
require 'gorillib/model/validate'
require 'gorillib/model/errors'
#
require 'gorillib/model/base'
require 'gorillib/model/schema_magic'

module Gorillib
  module Model
    def extra_attributes
      @_extra_attributes || {}
    end
    module ClassMethods
      # @return [{Symbol => Gorillib::Model::Field}]
      def fields
        return @_fields if defined?(@_fields)
        @_fields = ancestors.reverse.inject({}){|acc, ancestor| acc.merge!(ancestor.try(:_own_fields) || {}) }.merge(@_own_fields)
      end
    end
  end
end

require 'gorillib/model/field'
require 'gorillib/model/defaults'
require 'gorillib/model/positional_fields'

require_relative 'rucker/keyed_collection'
require_relative 'rucker/models'
require_relative 'rucker/runner'

module Rucker
  extend self

  HUMAN_TO_BYTES = { 'GB' => 2**30, 'MB' => 2**20, 'kB' => 2**10, 'B' => 1 }
  def human_to_bytes(num, units)
    raise "Can't dehumanize #{[num, units].inspect}" if not HUMAN_TO_BYTES.include?(units)
    (num.to_f * HUMAN_TO_BYTES[units]).to_i
  end

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

end
