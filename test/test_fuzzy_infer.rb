# encoding: UTF-8
require 'helper'

describe FuzzyInfer do
  describe FuzzyInfer::ActiveRecordClassMethods do
    it 'adds a way to configure a FuzzyInferenceMachine' do
      CBECS.respond_to?(:fuzzy_infer).must_equal true
    end
  end
  
  describe FuzzyInfer::ActiveRecordInstanceMethods do
    it 'adds a way to infer a particular target (field)' do
      CBECS.new.respond_to?(:fuzzy_infer).must_equal true
    end
    it 'adds a way to get a FIM object' do
      CBECS.new.respond_to?(:fuzzy_inference_machine).must_equal true
    end
    it "creates a new FIM object" do
      e = CBECS.new.fuzzy_inference_machine(:electricity_per_room_night)
      e.must_be_instance_of FuzzyInfer::FuzzyInferenceMachine
    end
  end
  # CBECS.new(:heating_degree_days => 2778, :lodging_rooms => 20).fuzzy_infer(:electricity_per_room_night)
  
  describe FuzzyInfer::FuzzyInferenceMachine do
    before do
      @kernel = CBECS.new(:heating_degree_days => 2778, :cooling_degree_days => 400, :lodging_rooms => 20, :principal_activity => 'Partying')
      @e = @kernel.fuzzy_inference_machine(:electricity_per_room_night)
    end
    describe '#basis' do
      it "is the union of the kernel's attributes with the basis" do
        @e.basis.must_equal :lodging_rooms => 20, :heating_degree_days => 2778.0, :cooling_degree_days => 400.0
      end
    end
    describe "the temp table" do
      it "excludes rows from the original table where basis or target is nil, but includes rows where they are 0" do
        ActiveRecord::Base.connection.select_value(@e.arel_table.project('COUNT(*)').to_sql).to_f.must_equal 192
      end
    end
    describe '#sigma' do
      it "is calculated from the original table, but only those rows that are also in the temp table" do
        @e.sigma[:heating_degree_days].must_be_close_to 411.9, 0.1
        @e.sigma[:cooling_degree_days].must_be_close_to 267.6, 0.1
        @e.sigma[:lodging_rooms].must_be_close_to 55.0, 0.1
      end
    end
    describe '#membership' do
      it 'depends on the kernel' do
        @e.membership.must_match %r{\(POW\(.heating_degree_days_n_w_\d+_\d+.,\ 0\.8\)\ \+\ POW\(.cooling_degree_days_n_w_\d+_\d+.,\ 0\.8\)\)\ \*\ POW\(.lodging_rooms_n_w_\d+_\d+.,\ 0\.8\)}
      end
    end
    describe '#infer' do
      it 'guesses!' do
        @e.infer.must_be_close_to 17.75, 0.01
      end
    end
    describe 'optimizations' do
      it "can run multiple numbers at once" do
        # dry run
        @kernel.fuzzy_infer :electricity_per_room_night
        @kernel.fuzzy_infer :natural_gas_per_room_night
        @kernel.fuzzy_infer :fuel_oil_per_room_night
        # end
        e1 = n1 = f1 = e2 = n2 = f2 = nil
        uncached_time = Benchmark.realtime do
          e1 = @kernel.fuzzy_infer :electricity_per_room_night
          n1 = @kernel.fuzzy_infer :natural_gas_per_room_night
          f1 = @kernel.fuzzy_infer :fuel_oil_per_room_night
        end
        cached_time = Benchmark.realtime do
          e2, n2, f2 = @kernel.fuzzy_infer :electricity_per_room_night, :natural_gas_per_room_night, :fuel_oil_per_room_night
        end
        (uncached_time / cached_time).must_be :>, 2
        e2.must_equal e1
        n2.must_equal n1
        f2.must_equal f1
      end
    end
  end
end
