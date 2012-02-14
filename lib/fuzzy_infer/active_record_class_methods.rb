require 'hashie/mash'

module FuzzyInfer
  module ActiveRecordClassMethods
    def fuzzy_infer(options = {})
      options = ::Hashie::Mash.new options
      options.target.each do |target|
        Registry.instance[name] ||= {}
        Registry.instance[name][target] = options
      end
    end
  end
end
