require 'yaml'
require 'multi_json'
require 'docker'
require 'thread'


require 'gorillib'
require 'gorillib/pathname'
require 'gorillib/hash/keys'
require 'gorillib/array/wrap'
require 'gorillib/system/runner'
require 'gorillib/object/try'
require 'gorillib/string/human'
# workaround for gorillib's try
require_relative 'rucker/utils/try'
require 'gorillib/model'
require 'gorillib/model/positional_fields'
require 'gorillib/model/serialization'

require_relative 'configliere/overrides'

require_relative 'rucker/error'

require_relative 'rucker/utils/formatter'
require_relative 'rucker/utils'
require_relative 'rucker/keyed_collection'
#
require_relative 'rucker/actual/actual_container'
require_relative 'rucker/actual/actual_image'
#
require_relative 'rucker/manifest/base'
require_relative 'rucker/manifest/port_binding'
require_relative 'rucker/manifest/image'
require_relative 'rucker/manifest/image'
require_relative 'rucker/manifest/container'
require_relative 'rucker/manifest/cluster'
require_relative 'rucker/manifest/world'
#
require_relative 'rucker/runner'
require_relative 'rucker/formatter/table'

module Rucker

  @config = Configliere::Param.new.use(:commandline, :config_file)
  def self.config(val=nil)
    val ? @config[val] : @config
  end

  config.define :verbose, type: :boolean, default: false, description: "Emit additional low-level progress logging"
  config.define :full,    type: :boolean, default: false, description: "Causes charts to output all fields, rather than enforcing column uniformity"
  config.define :world,   type: Symbol, default: :local, description: "The name of the world to load from the layout yaml file"
  config.define :layout_file, default: './rucker.yaml', description: "The layout file to load"

  def self.reload!
    lib_dir = File.dirname(__FILE__)
    %w[docker docker/image docker/util].each do |fn|
      load File.join(lib_dir, "../../vendor/docker-api/lib", "#{fn}.rb")
    end
    %w[ utils
         manifest/base manifest/world manifest/cluster
         manifest/image manifest/container
         actual/actual_image    actual/actual_container
         actual/tutum_container
         utils/formatter ].each do |fn|
      load File.join(lib_dir, "rucker/#{fn}.rb")
    end
    true
  end

  #
  # Rucker utility methods are in 'rucker/utils{.rb,/*.rb}'
  #

end
