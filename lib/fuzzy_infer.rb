require 'active_support/core_ext'

require "fuzzy_infer/version"
require 'fuzzy_infer/registry'
require 'fuzzy_infer/active_record_class_methods'
require 'fuzzy_infer/active_record_instance_methods'
require 'fuzzy_infer/fuzzy_inference_machine'

module FuzzyInfer
  # Your code goes here...
end

ActiveRecord::Base.send :include, FuzzyInfer::ActiveRecordInstanceMethods
ActiveRecord::Base.extend FuzzyInfer::ActiveRecordClassMethods
