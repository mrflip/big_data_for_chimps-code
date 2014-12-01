module Rucker

  class App
    configuration do |cfg|
      cfg.setting :verbose
      cfg.setting :world, doc: '...'
    end

    namespace(:images) do
      #
      # the block is called, not instance eval'ed, so you're still at class level
      # with access to class methods &c
      configuration do |cfg|
        # these are specific to
        cfg.setting :registry, doc: 'the registry to hit'
      end

      # applied to all child objects
      depends_on :refresh_worlds, except: :help

      # this is just sugar for
      #     class App::ImagesTasks::Ls < Configliere::Task
      #       # ... stuff inside that block ....
      #     end
      #     App::Images.register_task(App::Images::Ls)
      #
      # override the superclass with an optional second arg; these are equivalent:
      #     task(:ls, 'world_eater')
      #     task(:ls, App::WorldEater)
      #     class App::ImagesTasks::Ls < App::WorldEater ; ... ; end

      task(:ls) do
        # dependencies ask that it be invoked once before runnning this task,
        # but not many times
        depends_on :refresh_worlds

        configuration do |cfg|
          # ...
        end

        def run
        end
      end

    end
    task(:images) do
      invokes 'images:ls'
    end

  end


  module Command

    self.included do |base|
      base.instance_eval do
        include Gorillib::Model
        include Gorillib::AccessorFields
        accessor_field :parent
        #
        class_attribute :tasks
        self.tasks = []
        #
        # HACK for now, so I can figure out what I want: class and object share
        # the config. This is bad because of the resolve! stuff being
        # once-only-kinda.
        class_attribute :_config
        self._config = {}
      end
    end

    module ClassMethods
      def configuration(&blk)
        cfg = Rucker::Command::Configuration.new
        blk.call(cfg)
      end

    end

    module Configuration
      def setting(name, opts={})
        opts[:description] = opts[:doc] if opts[:doc]
        opts.delete(:type) if [:String, :string, :Pathname, :pathname].include?(opts[:type].to_s.to_sym)
        config.define(name, opts)
      end
    end

  end

end
