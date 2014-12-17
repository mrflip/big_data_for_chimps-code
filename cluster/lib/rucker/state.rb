
#
# * goals   -- named sets of states to reach. Principally:
#   - up:    component is in full operation
#   - ready: component exists and has durable identifiers. It may or may not be doing anything.
#   - down:  component is not active. It may or may not exist.
#   - clear: component does not exist.
#
# * state   -- reported conditions of the system.
#
# * action  -- imperative call for change.
#
# * advance -- request for the component to approach given goal by either
#   - taking an action toward that goal;
#   - returning a list of [object, goal] pairs that are prerequisite (note: goal, not action);
#   - advising a wait because they are in a transitional state; or
#   - declaring failure
#
#
#                    logical       actual
#     information    goal          state
#     action         advance       action
#
# ...
# .
#

class Rucker::Manifest::Container
  # include HasGoals

  BEFORES = {} unless defined?(BEFORES)
  GOALS   = {} unless defined?(GOALS)

  def self.before(goal_name, &blk)
    BEFORES[goal_name] = blk
  end

  def self.goal(goal_name, &blk)
    BEFORES[goal_name] ||= ->(*){ [] }
    define_method("advance_#{goal_name}", &blk)
    define_method(goal_name) do
      return :success if at_goal?(goal_name)
      remaining = check_preconditions(goal_name)
      return remaining if remaining.present?
      self.send("advance_#{goal_name}")
    end
  end

  def run_before(goal_name)
    self.instance_eval(&BEFORES[goal_name])
  end

  def check_preconditions(goal_name)
    conds = self.instance_eval(&BEFORES[goal_name])
    conds.reject do |obj, goal|
      obj.public_send("#{goal}?")
    end
  end

  def at_goal?(gl)
    self.send("#{gl}?")
  end

  def self.advance(goalset)
    succs = [] ; waits = [] ; fails = []
    needs = Hash.new{|h,k| h[k] = [] } # autovivify array
    #
    next_goalset = Set.new
    #
    goalset.each do |obj, goal|
      ctr         = Rucker.world.container(obj)
      result      = ctr.public_send(goal)
      result_info = { was: result }
      #
      case result
      when :success  then succs << obj
      when Exception then fails << result
      when :wait     then waits << obj
      when /!$/      then waits << obj # acted!
      when Array
        result.each do |other, dep_goal|
          next_goalset << [other.name, dep_goal]
        end
        result_info = { needs: result.map{|other, dep_goal| "#{other.desc} -> #{dep_goal}" }.join(', ') }
      end
      Rucker.progress(goal, ctr, {indent: 2, state: ctr.state}.merge(result_info))
      #
      next_goalset << [obj, goal]
    end
    #
    [succs, waits, fails, next_goalset]
  end

  def self.reach(clxn, goal)
    goalset = Set.new
    clxn.each{|ctr| goalset << [ctr.name, goal] }
    succs = [] ; waits = clxn.to_a; fails = []
    100.times do
      Rucker.progress goal, goalset.map(&:first).join(', '), indent: 0
      succs, waits, fails, goalset = advance(goalset)
      break if (succs.size == goalset.size)
      sleep 1
      Rucker.world.refresh!
    end
    Hash[clxn.map{|ctr| [ctr.name, ctr.state] }]
  end

  before :up do
    [ [image, :up], [self, :ready] ] +
      linked_containers.values.map{|ctr| [ctr, :up] } +
      volume_containers.values.map{|ctr| [ctr, :up] }
  end

  def unpause!() _unpause ; end
  def start!()   _start   ; end
  def create!()  _create  ; end
  def stop!()    _stop    ; end
  def remove!()  _remove  ; end

  goal :up do
    case state
    when :paused       then unpause! ; return :unpause!
    when :stopped      then start!   ; return :start!
    when :init         then start!   ; return :start!
    when :starting, :restart, :scaling, :redeploying, :stopping, :partly
      return :wait
    else
      # :not_running, :absent fall to here
      return RuntimeError.new("Should not see state #{state} for #{self}")
    end
  end

  before :ready do
    [ [image, :up] ] +
      linked_containers.values.map{|ctr| [ctr, :up] } +
      volume_containers.values.map{|ctr| [ctr, :up] }
  end

  goal :ready do
    case state
    when :absent       then create!  ; return :create!
    when :starting, :restart, :scaling, :redeploying, :stopping, :partly
      return :wait
    when :not_running
      warn "Not running state -- must remove and then ready"
      remove!
      return :acted
    else
      return RuntimeError.new("Should not see state #{state} for #{self}")
    end
  end

  # Take the next step towards the down goal
  goal :down do
    case state
    when :running      then stop!   ;  return :stop!
    when :paused       then stop!   ;  return :stop!
    when :partly       then stop!   ;  return :stop!
    when :starting, :restart, :scaling, :redeploying, :stopping
      return :wait
    else
      return RuntimeError.new("Should not see state #{state} for #{self}")
    end
  end

  before :clear do
    [ [self, :down] ]
  end

  # Take the next step towards the clear goal
  goal :clear do
    case state
    when :not_running  then remove!      ; return :remove!
    when :stopped      then remove!      ; return :remove!
    when :init         then remove!      ; return :remove!
    when :starting, :restart, :scaling, :redeploying, :stopping
      return :wait
    else
      # includes :running, :paused, :partly
      return RuntimeError.new("Should not see state #{state} for #{self}")
    end
  end

end
