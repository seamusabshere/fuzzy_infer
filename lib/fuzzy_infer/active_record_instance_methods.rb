module FuzzyInfer
  module ActiveRecordInstanceMethods
    # Returns a new FuzzyInferenceMachine instance that can infer this target (field)
    def fuzzy_inference_machine(target)
      target = target.to_sym
      FuzzyInferenceMachine.new self, target, Registry.config_for(self.class.name, target)
    end
    
    # Shortcut to creating a FIM and immediately calling it
    def fuzzy_infer(target)
      fuzzy_inference_machine(target).infer
    end
  end
end
