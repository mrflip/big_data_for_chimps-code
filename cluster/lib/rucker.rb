require 'yaml'
require 'multi_json'
require 'docker'

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
  extend self

  def self.world
    @world ||= Rucker::Manifest::World.load(Pathname.of(:cluster_layout), 'local')
  end

  #
  # Rest of Rucker utility methods are in 'rucker/utils/*.rb'
  #
end
