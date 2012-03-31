require 'singleton'

module FuzzyInfer
  class Registry < ::Hash
    class << self
      def config_for(class_name, targets)
        raise %{[fuzzy_infer] Zero machines are defined on #{class_name}.} unless instance.has_key?(class_name)
        unless k_v = instance[class_name].detect { |k, _| (targets & k) == targets }
          raise %{[fuzzy_infer] Target #{targets.inspect} is not available on #{class_name}.}
        end
        k_v.last
      end
    end
    
    include ::Singleton
  end
end
