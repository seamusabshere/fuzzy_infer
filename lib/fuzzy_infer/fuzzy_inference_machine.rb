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
      @started = true
      execute %{CREATE TABLE #{tmp_table} LIKE #{quoted_table_name}}
      execute %{INSERT INTO #{tmp_table} SELECT * FROM #{quoted_table_name} WHERE #{target_not_null_sql} AND #{basis_not_null_sql}}
      execute %{ALTER TABLE #{tmp_table} ADD COLUMN fuzzy_weighted_value FLOAT default null}
      execute %{ALTER TABLE #{tmp_table} ADD COLUMN fuzzy_membership FLOAT default null}
      execute %{ALTER TABLE #{tmp_table} #{weight_create_columns_sql}}
      execute %{UPDATE #{tmp_table} SET #{weight_calculate_sql}}
      weight_normalize_frags.each do |sql|
        execute sql
      end
      execute %{UPDATE #{tmp_table} SET fuzzy_membership = #{membership_sql}}
      execute %{UPDATE #{tmp_table} SET fuzzy_weighted_value = fuzzy_membership * #{quote_column_name(target)}}
      select_value %{SELECT SUM(fuzzy_weighted_value)/SUM(fuzzy_membership) FROM #{tmp_table}}
    end
    
    def basis
      @basis ||= kernel.attributes.symbolize_keys.slice(*config.basis).reject { |k, v| v.nil? }
    end
    
    def sigma
      @sigma ||= basis.inject({}) do |memo, (k, v)|
        memo[k] = select_value %{SELECT #{sigma_sql(k, v)} FROM #{quoted_table_name}}
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
    
    def membership_sql
      if config.weight
        "(#{membership}) * #{quote_column_name(config.weight.to_s)}"
      else
        membership
      end
    end
    
    def weight_normalize_frags
      basis.keys.map do |k|
        "UPDATE #{tmp_table} AS dest_t, (SELECT MAX(#{quote_column_name("#{k}_w")}) AS m FROM #{tmp_table}) AS src_t SET dest_t.#{quote_column_name("#{k}_n_w")} = #{quote_column_name("#{k}_w")} / src_t.m"
      end
    end
    
    # 1/(sigma*SQRT(2*pi)) *EXP(-((xi -mu)^2)/(2*sigma^2))
    def weight_calculate_sql
      basis.keys.map do |k|
        "#{quote_column_name("#{k}_w")} = 1.0 / (#{sigma[k]}*SQRT(2*PI())) * EXP(-((#{quote_column_name(k)} - #{basis[k]})^2)/(2*#{sigma[k]}^2))"
      end.join(', ')
    end
    
    def sigma_sql(column_name, value)
      sql = config.sigma.dup
      sql.gsub! ':column', quote_column_name(column_name)
      sql.gsub! ':value', value.to_f.to_s
      sql
    end
    
    def tmp_table
      @tmp_table ||= "fuzzy_infer_#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}" #Kernel.rand(1e11)
    end
    
    def weight_create_columns_sql
      basis.keys.inject([]) do |memo, k|
        memo << "ADD COLUMN #{quote_column_name("#{k}_w")} FLOAT default null" # AFTER #{quote_column_name(k)}
        memo << "ADD COLUMN #{quote_column_name("#{k}_n_w")} FLOAT default null"
        memo
      end.flatten.join ', '
    end
    
    def basis_not_null_sql
      basis.keys.map do |basis|
        "#{quoted_table_name}.#{quote_column_name(basis)} <> 0"
      end.join ' AND '
    end
    
    # not config.target (the list of all possible targets), just this machine's target
    def target_not_null_sql
      "#{quoted_table_name}.#{quote_column_name(target)} <> 0"
    end
    
    def connection
      kernel.connection
    end
    
    def active_record_class
      kernel.class
    end
    
    delegate :quoted_table_name, :to => :active_record_class
    delegate :execute, :quote_column_name, :select_value, :to => :connection
  end
end

