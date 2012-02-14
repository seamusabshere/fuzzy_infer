require 'singleton'

module FuzzyInfer
  class Registry < ::Hash
    class << self
      def config_for(class_name, target)
        raise %{[fuzzy_infer] Zero machines are defined on #{class_name}.} unless instance.has_key?(class_name)
        raise %{[fuzzy_infer] Target #{target.inspect} is not available on #{class_name}.} unless instance[class_name].has_key?(target)
        instance[class_name][target]
      end
    end
    
    include ::Singleton
  end
end
