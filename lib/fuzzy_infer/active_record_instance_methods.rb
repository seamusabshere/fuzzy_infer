module FuzzyInfer
  module ActiveRecordInstanceMethods
    def fuzzy_inference_machine(target)
      target = target.to_sym
      FuzzyInferenceMachine.new self, target, Registry.config_for(self.class.name, target)
    end
    
    def fuzzy_infer(target)
      fuzzy_inference_machine(target).infer
    end
  end
end
