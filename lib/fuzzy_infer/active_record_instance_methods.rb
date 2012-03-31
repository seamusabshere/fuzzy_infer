module FuzzyInfer
  module ActiveRecordInstanceMethods
    # Returns a new FuzzyInferenceMachine instance that can infer this target (field)
    def fuzzy_inference_machine(*targets)
      FuzzyInferenceMachine.new self, targets, Registry.config_for(self.class.name, targets)
    end
    
    # Shortcut to creating a FIM and immediately calling it
    def fuzzy_infer(*targets)
      fuzzy_inference_machine(*targets).infer
    end
  end
end
