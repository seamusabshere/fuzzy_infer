require 'hashie/mash'

module FuzzyInfer
  module ActiveRecordClassMethods
    # Configure fuzzy inferences
    # see test/helper.rb for an example
    def fuzzy_infer(options = {})
      options = ::Hashie::Mash.new options
      Registry.instance[name] ||= {}
      Registry.instance[name][options.target] = options
    end
  end
end
