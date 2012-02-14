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
      @kernel = CBECS.new(:heating_degree_days => 2778, :lodging_rooms => 20, :principal_activity => 'Partying')
      @e = @kernel.fuzzy_inference_machine(:electricity_per_room_night)
    end
    describe '#basis' do
      it "is the union of the kernel's attributes with the basis" do
        @e.basis.must_equal :heating_degree_days => 2778, :lodging_rooms => 20
      end
    end
    describe "the temp table" do
      it "excludes rows from the original table where basis or target is nil, but includes rows where they are 0" do
        ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{@e.send(:tmp_table)}").must_equal 192
      end
    end
    describe '#sigma' do
      it "is calculated from the original table, but only those rows that are also in the temp table" do
        @e.sigma[:heating_degree_days].must_be_close_to 411.2, 0.1
        @e.sigma[:lodging_rooms].must_be_close_to 55.0, 0.1
      end
    end
    describe '#membership' do
      it 'depends on the kernel' do
        @e.membership.must_equal 'POW(`heating_degree_days_n_w`,0.8) * POW(`lodging_rooms_n_w`,0.8)'
      end
    end
    describe '#infer' do
      it 'guesses!' do
        @e.infer.must_be_close_to 18.35, 0.01
      end
    end
  end
end
