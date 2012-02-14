require 'bundler/setup'

require 'active_record'
case ENV['DB_ADAPTER']
when 'postgresql'
  adapter = 'postgresql'
  username = ENV['POSTGRES_USERNAME'] || `whoami`.chomp
  password = ENV['POSTGRES_PASSWORD']
  database = ENV['POSTGRES_DATABASE'] || 'test_fuzzy_infer'
else
  adapter = 'mysql2'
  database = 'test_fuzzy_infer'
  username = 'root'
  password = 'password'
end
config = {
  'encoding' => 'utf8',
  'adapter' => adapter,
  'database' => database,
}
config['username'] = username if username
config['password'] = password if password
ActiveRecord::Base.establish_connection config
require 'logger'
ActiveRecord::Base.logger = Logger.new $stderr
ActiveRecord::Base.logger.level = Logger::DEBUG

require 'earth'
if ENV['RUN_DATA_MINER'] == 'true'
  Earth.init :hospitality, :load_data_miner => true
  ActiveRecord::Base.logger.level = Logger::INFO
  CommercialBuildingEnergyConsumptionSurveyResponse.run_data_miner!
  $stderr.puts "Done!"
  exit
end

Earth.init :hospitality

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
MiniTest::Unit.runner = MiniTest::SuiteRunner.new
MiniTest::Unit.runner.reporters << MiniTest::Reporters::SpecReporter.new

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'fuzzy_infer'
require 'ruby-debug'
# class MiniTest::Spec
# end

CBECS = CommercialBuildingEnergyConsumptionSurveyResponse
class CBECS < ActiveRecord::Base
  fuzzy_infer :target     => [:electricity_per_room_night, :natural_gas_per_room_night, :fuel_oil_per_room_night, :district_heat_per_room_night], # list of columns that this model is designed to infer
              :basis      => [:lodging_rooms, :construction_year, :heating_degree_days, :cooling_degree_days, :floors, :ac_coverage],             # list of columns that are believed to affect energy use (aka MU)
              :sigma      => "(STDDEV(:column)/5)+(ABS(AVG(:column)-:value)/3)",                                                                  # empirically determined formula (SQL!) that captures the desired sample size once all the weights are compiled, across the full range of possible mu values
              :membership => :energy_use_membership,                                                                                              # name of instance method to be called on kernel
              :weight     => :weighting                                                                                                           # (optional) a pre-existing row weighting, if any, provided by the dataset authors
  
  # empirically determined formula that minimizes variance between real and predicted energy use
  # SQL! - :heating_degree_days_n_w will be replaced with, for example, `tmp_table_9301293.hdd_normalized_weight`
  def energy_use_membership(basis)
    case basis.keys.sort
    when [:heating_degree_days, :lodging_rooms]
      "POW(:heating_degree_days_n_w,0.8) * POW(:lodging_rooms_n_w,0.8)"
    when [:heating_degree_days]
      "POW(:heating_degree_days_n_w,0.8)"
    else
      raise "#{basis.inspect} not covered by membership function"
    end
  end
end
