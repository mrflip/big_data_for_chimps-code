module Rucker::RakeUtils

  def task_args(name, *param_names, &block)
    task(name, *param_names) do |task, task_params|
      args = param_names.map{|param| task_params[param] || ENV[param.to_s.upcase] }
      opts  = {}
      block.call(*args, opts)
    end
  end

  def container_task(name, &block)
    task(name, :names) do |task, task_params|
      names = task_params[:names] || ENV['CONTAINER']
      if names.present?
        names = names.split(/[\+,]\s*/).map(&:to_sym)
        names = [:_all] if names.include?(:all)
      end
      opts  = {}
      if (ENV['show_output'] || ENV['SHOW_OUTPUT']) == 'true'
        opts[:attaches] = ['STDOUT', 'STDERR']
      else
        opts[:detach] = true
      end
      block.call(names, opts)
    end
    # .enhance{ Rake::Task[:info].execute }
  end

end
