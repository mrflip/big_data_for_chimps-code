
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

module Rucker
  module HasGoals
    extend Gorillib::Concern

    def check_preconditions(target)
      send("_before_#{target}").reject do |obj, dep_goal|
        obj.at_goal?(dep_goal)
      end
    end

    def at_goal?(gl)
      self.send("#{gl}?")
    end

    module ClassMethods
      def before(target, &blk)
        define_method("_before_#{target}", &blk)
      end
      NO_PRECONDITIONS = ->(*){ [] } unless defined?(NO_PRECONDITIONS)

      def goal(target, &blk)
        define_method("_advance_#{target}", &blk)
        before(target, &NO_PRECONDITIONS) unless method_defined?("_before_#{target}")
        define_method(target) do
          return :success if at_goal?(target)
          remaining = check_preconditions(target)
          return remaining if remaining.present?
          return :wait    if transition?
          self.send("_advance_#{target}")
        end
      end

      def advance(goalset)
        succs = [] ; waits = [] ; fails = []
        needs = Hash.new{|h,k| h[k] = [] } # autovivify array
        #
        next_goalset = Set.new
        #
        goalset.each do |obj, goal|
          Rucker.progress(goal, obj, {phase: 'prior', indent: 2, state: [obj.state, ';'] })
          result      = obj.public_send(goal)
          result_info = { was: result }
          #
          case result
          when :success  then succs << obj.name; result_info = { success: goal }
          when Exception then fails << result;   result_info = { error:   result }
          when :wait     then waits << obj.name; result_info = { wait:    'patiently' }
          when /^(.*)!$/ then waits << obj.name; result_info = { ran:     $1 }
          when Array
            result.each do |other, dep_goal|
              next_goalset << [other, dep_goal]
            end
            result_info = { needs: result.map{|other, dep_goal| "#{other.desc} -> #{dep_goal}" }.join(', ') }
          end
          Rucker.progress(goal, obj, {indent: 2, state: [obj.state, ';'] }.merge(result_info))
          #
          next_goalset << [obj, goal]
        end
        #
        [succs, waits, fails, next_goalset]
      end

      def reach(clxn, goal)
        goalset = Set.new
        clxn.each{|obj| goalset << [obj, goal] }
        succs = [] ; waits = []; fails = []
        100.times do
          Rucker.progress goal, goalset.map{|obj, goal| "#{obj.name}->#{goal}" }.join(', '), indent: 0
          succs, waits, fails, goalset = advance(goalset)
          break if (succs.size == goalset.size)
          sleep 1
          Rucker.world.refresh!
        end
        Hash[clxn.map{|obj| [obj.name, obj.state] }]
      end
    end

  end

  module CollectsGoals
    def up(*args)
      refresh!
      item_type.reach(self.items, :up)
    end

    def ready(*args)
      refresh!
      item_type.reach(self.items, :ready)
    end

    def down(*args)
      refresh!
      item_type.reach(self.items.reverse, :down)
    end

    def clear(*args)
      refresh!
      item_type.reach(self.items.reverse, :clear)
    end

    def up?()    items.all?(&:up?)    ; end
    def ready?() items.all?(&:ready?) ; end
    def down?()  items.all?(&:down?)  ; end
    def clear?() items.all?(&:clear?) ; end

    def state
      map(&:state).uniq.compact
    end
  end

end
