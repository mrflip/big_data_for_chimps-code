# -*- coding: utf-8 -*-
Bundler.require(:default, :docker, :tutum)
require 'logger'
::Log = Logger.new($stderr) unless defined?(Log)
Log.level = Logger::DEBUG
RestClient.log = Log

require_relative 'tutum/tutum_base'
require_relative 'tutum/tutum_container'
require_relative 'tutum/tutum_service'
require_relative 'tutum/tutum_provider'
