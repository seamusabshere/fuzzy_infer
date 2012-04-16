#!/usr/bin/env rake
require "bundler/gem_tasks"

require 'rake'
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'yard'
YARD::Rake::YardocTask.new do |y|
  y.options << '--no-private' << '--title' << "fuzzy_infer: Fuzzy set analysis in Ruby"
end
