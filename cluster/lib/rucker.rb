require 'yaml'
require 'rake'
require 'rake/file_utils.rb'
require 'multi_json'
require 'docker'
require_relative 'docker/container_extensions'
require_relative 'docker/image_extensions'

require 'gorillib'
require 'gorillib/pathname'
require 'gorillib/hash/keys'
require 'gorillib/array/wrap'
require 'gorillib/system/runner'

require 'gorillib/object/try'

# workaround for a bug in gorillib try
class Object
  def try(*a, &b)
    if a.empty? && block_given?
      yield self
    elsif !a.empty? && !respond_to?(a.first, true)
      nil
    else
      __send__(*a, &b)
    end
  end
end

require 'gorillib/model'
require 'gorillib/model/positional_fields'
require 'gorillib/model/serialization'

require_relative 'rucker/utils'
require_relative 'rucker/keyed_collection'
require_relative 'rucker/manifest/base'
require_relative 'rucker/manifest/port_binding'
require_relative 'rucker/manifest/image'
require_relative 'rucker/models'
require_relative 'rucker/runner'
require_relative 'rucker/formatter'
require_relative 'rucker/formatter/table'
require_relative 'rucker/formatter/table'
