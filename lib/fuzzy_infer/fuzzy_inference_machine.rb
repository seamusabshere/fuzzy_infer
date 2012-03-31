module FuzzyInfer
  class FuzzyInferenceMachine
    MYSQL_ADAPTER_NAME = /mysql/i

    attr_reader :kernel
    attr_reader :targets
    attr_reader :config

    def initialize(kernel, targets, config)
      @kernel = kernel
      @targets = targets
      @config = config
    end

    def infer
      calculate_table!
      pieces = targets.map do |target|
        "SUM(#{my(target, :v)})/SUM(#{my(:fuzzy_membership)})"
      end
      values = select_rows(%{SELECT #{pieces.join(', ')} FROM #{table_name}}).first.map do |value|
        value.nil? ? nil : value.to_f
      end
      execute %{DROP TABLE #{table_name}}
      if targets.length == 1
        return values.first
      else
        return *values
      end
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
        memo[k] = select_value(%{SELECT #{sigma_sql(k, v)} FROM #{kernel.class.quoted_table_name} WHERE #{all_targets_not_null_sql} AND #{basis_not_null_sql}}).to_f
        memo
      end
    end

    def membership
      return @membership if @membership
      sql = kernel.send(config.membership, basis).dup
      basis.keys.each do |k|
        sql.gsub! ":#{k}_n_w", my(k, :n_w)
      end
      @membership = sql
    end

    private

    def calculate_table!
      return if table_exists?(table_name)
      mysql = connection.adapter_name =~ MYSQL_ADAPTER_NAME
      execute %{CREATE TEMPORARY TABLE #{table_name} #{'ENGINE=MEMORY' if mysql} AS SELECT * FROM #{kernel.class.quoted_table_name} WHERE #{all_targets_not_null_sql} AND #{basis_not_null_sql}}
      execute %{ALTER TABLE #{table_name} #{additional_column_definitions.join(',')}}
      execute %{ANALYZE #{'TABLE' if mysql} #{table_name}}
      execute %{UPDATE #{table_name} SET #{weight_calculate_sql}}
      weight_normalize_frags.each do |sql|
        execute sql
      end
      execute %{UPDATE #{table_name} SET #{my(:fuzzy_membership)} = #{membership_sql}}
      execute %{UPDATE #{table_name} SET #{target_setters.join(', ')}}
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
        max = select_value("SELECT MAX(#{my(k, :w)}) FROM #{table_name}").to_f
        "UPDATE #{table_name} SET #{my(k, :n_w)} = #{my(k, :w)} / #{max}"
      end
    end

    def target_setters
      targets.map do |target|
        %{#{my(target, :v)} = #{my(:fuzzy_membership)} * #{quote_column_name(target)}}
      end
    end

    def weight_calculate_sql
      basis.keys.map do |k|
        "#{my(k, :w)} = 1.0 / (#{sigma[k]}*SQRT(2*PI())) * EXP(-(POW(#{quote_column_name(k)} - #{basis[k]},2))/(2*POW(#{sigma[k]},2)))"
      end.join(', ')
    end

    def sigma_sql(column_name, value)
      sql = config.sigma.dup
      sql.gsub! ':column', quote_column_name(column_name)
      sql.gsub! ':value', value.to_f.to_s
      sql
    end

    def randomness
      @randomness ||= [Time.now.strftime('%H%M%S'), Kernel.rand(1e5)].join('_')
    end

    def table_name
      @table_name ||= "fuzzy_infer_#{randomness}"
    end

    def additional_column_definitions
      cols = []
      cols << "ADD COLUMN #{my(:fuzzy_membership)} FLOAT DEFAULT NULL"
      basis.keys.each do |k|
        cols << "ADD COLUMN #{my(k, :w)} FLOAT DEFAULT NULL"
        cols << "ADD COLUMN #{my(k, :n_w)} FLOAT DEFAULT NULL"
      end
      targets.each do |target|
        cols << "ADD COLUMN #{my(target, :v)} FLOAT DEFAULT NULL"
      end
      cols
    end

    def basis_not_null_sql
      basis.keys.map do |basis|
        "#{quote_column_name(basis)} IS NOT NULL"
      end.join ' AND '
    end

    def all_targets_not_null_sql
      [config.target].flatten.map do |target|
        "#{quote_column_name(target)} IS NOT NULL"
      end.join ' AND '
    end

    def connection
      kernel.connection
    end

    def my(column_name, suffix = nil)
      quote_column_name([column_name, suffix, randomness].compact.join('_'))
    end

    delegate :execute, :quote_column_name, :select_value, :select_rows, :table_exists?, :to => :connection
  end
end

