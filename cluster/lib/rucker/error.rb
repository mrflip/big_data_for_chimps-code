module Rucker
  module Error
    class ParallelError < RuntimeError
      attr_accessor :errors

      def self.with_errors(errs)
        msg = "Errors in parallel tasks: #{errs.values.join(' // ')}"
        err = self.new(msg)
        err.errors = errs
        err
      end
    end
  end
end
