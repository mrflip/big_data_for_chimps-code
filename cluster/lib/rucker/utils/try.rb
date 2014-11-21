#
# workaround for a bug in gorillib try introduced in ruby 2.0
#
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
