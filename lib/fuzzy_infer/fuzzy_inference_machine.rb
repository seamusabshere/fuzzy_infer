module FuzzyInfer
  class FuzzyInferenceMachine
    
    attr_reader :kernel
    attr_reader :target
    attr_reader :config

    def initialize(kernel, target, config)
      @kernel = kernel
      @target = target
      @config = config
    end
    
    def infer
      calculate_table!
      retval = select_value(%{SELECT SUM(fuzzy_weighted_value)/SUM(fuzzy_membership) FROM #{table_name}}).to_f
      execute %{DROP TABLE #{table_name}}
      retval
    end
    
    # TODO technically I could use this to generate the SQL
    def arel_table
      calculate_table!
      Arel::Table.new table_name
    end
    
    def basis
      @basis ||= kernel.attributes.symbolize_keys.slice(*config.basis).reject { |k, v| v.nil? }
    end
    
    def sigma
      @sigma ||= basis.inject({}) do |memo, (k, v)|
        memo[k] = select_value(%{SELECT #{sigma_sql(k, v)} FROM #{active_record_class.quoted_table_name} WHERE #{target_not_null_sql} AND #{basis_not_null_sql}}).to_f
        memo
      end
    end
    
    def membership
      return @membership if @membership
      sql = kernel.send(config.membership, basis).dup
      basis.keys.each do |k|
        sql.gsub! ":#{k}_n_w", quote_column_name("#{k}_n_w")
      end
      @membership = sql
    end
    
    private
    
    def calculate_table!
      return if table_exists?(table_name)
      execute %{CREATE TEMPORARY TABLE #{table_name} AS SELECT * FROM #{active_record_class.quoted_table_name} WHERE #{target_not_null_sql} AND #{basis_not_null_sql}}
      execute %{ALTER TABLE #{table_name} #{weight_create_columns_sql}}
      execute %{ALTER TABLE #{table_name} ADD COLUMN fuzzy_membership FLOAT default null}
      execute %{ALTER TABLE #{table_name} ADD COLUMN fuzzy_weighted_value FLOAT default null}
      execute %{UPDATE #{table_name} SET #{weight_calculate_sql}}
      weight_normalize_frags.each do |sql|
        execute sql
      end
      execute %{UPDATE #{table_name} SET fuzzy_membership = #{membership_sql}}
      execute %{UPDATE #{table_name} SET fuzzy_weighted_value = fuzzy_membership * #{quote_column_name(target)}}
      nil
    end
    
    def membership_sql
      if config.weight
        "(#{membership}) * #{quote_column_name(config.weight.to_s)}"
      else
        membership
      end
    end
    
    def weight_normalize_frags
      basis.keys.map do |k|
        max = select_value("SELECT MAX(#{quote_column_name("#{k}_w")}) FROM #{table_name}").to_f
        "UPDATE #{table_name} SET #{quote_column_name("#{k}_n_w")} = #{quote_column_name("#{k}_w")} / #{max}"
      end
    end
    
    def weight_calculate_sql
      basis.keys.map do |k|
        "#{quote_column_name("#{k}_w")} = 1.0 / (#{sigma[k]}*SQRT(2*PI())) * EXP(-(POW(#{quote_column_name(k)} - #{basis[k]},2))/(2*POW(#{sigma[k]},2)))"
      end.join(', ')
    end
    
    def sigma_sql(column_name, value)
      sql = config.sigma.dup
      sql.gsub! ':column', quote_column_name(column_name)
      sql.gsub! ':value', value.to_f.to_s
      sql
    end
    
    def table_name
      @table_name ||= "fuzzy_infer_#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}_#{Kernel.rand(1e11)}"
    end
    
    def weight_create_columns_sql
      basis.keys.inject([]) do |memo, k|
        memo << "ADD COLUMN #{quote_column_name("#{k}_w")} FLOAT default null"
        memo << "ADD COLUMN #{quote_column_name("#{k}_n_w")} FLOAT default null"
        memo
      end.flatten.join ', '
    end
    
    def basis_not_null_sql
      basis.keys.map do |basis|
        "#{quote_column_name(basis)} IS NOT NULL"
      end.join ' AND '
    end
    
    def target_not_null_sql
      "#{quote_column_name(target)} IS NOT NULL"
    end
    
    def connection
      kernel.connection
    end
    
    def active_record_class
      kernel.class
    end
    
    delegate :execute, :quote_column_name, :select_value, :table_exists?, :to => :connection
  end
end

