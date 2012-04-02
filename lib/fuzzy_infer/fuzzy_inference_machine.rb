module FuzzyInfer
  class FuzzyInferenceMachine
    MYSQL_ADAPTER_NAME = /mysql/i

    attr_reader :kernel
    attr_reader :targets
    attr_reader :config

    delegate :execute, :quote_column_name, :to => :connection

    def initialize(kernel, targets, config)
      @kernel = kernel
      @targets = targets
      @config = config
    end

    def infer
      calculate_table!
      pieces = targets.map do |target|
        "SUM(#{qc(target, :v)})/SUM(#{qc(:fuzzy_membership)})"
      end
      values = connection.select_rows(%{SELECT #{pieces.join(', ')} FROM #{table_name}}).first.map do |value|
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

    def membership
      return @membership if @membership
      sql = kernel.send(config.membership, basis).dup
      basis.keys.each do |k|
        sql.gsub! ":#{k}_n_w", qc(k, :n_w)
      end
      @membership = sql
    end

    private

    def calculate_table!
      return if connection.table_exists?(table_name)
      mysql = connection.adapter_name =~ MYSQL_ADAPTER_NAME
      execute %{CREATE TEMPORARY TABLE #{table_name} #{'ENGINE=MEMORY' if mysql} AS SELECT * FROM #{kernel.class.quoted_table_name} WHERE #{all_targets_not_null_condition} AND #{basis_not_null_condition}}
      execute %{ALTER TABLE #{table_name} #{additional_column_definitions.join(', ')}}
      execute %{ANALYZE #{'TABLE' if mysql} #{table_name}}
      execute %{UPDATE #{table_name} SET #{weight_calculators.join(', ')}}
      execute %{UPDATE #{table_name} SET #{weight_normalizers.join(', ')}}
      execute %{UPDATE #{table_name} SET #{membership_setter}}
      execute %{UPDATE #{table_name} SET #{target_setters.join(', ')}}
      nil
    end

    def membership_setter
      right = if config.weight
        "(#{membership}) * #{quote_column_name(config.weight.to_s)}"
      else
        membership
      end
      "#{qc(:fuzzy_membership)} = #{right}"
    end

    def target_setters
      targets.map do |target|
        %{#{qc(target, :v)} = #{qc(:fuzzy_membership)} * #{quote_column_name(target)}}
      end
    end

    def weight_calculators
      basis.keys.map do |k|
        "#{qc(k, :w)} = 1.0 / (#{sigma[k]}*SQRT(2*PI())) * EXP(-(POW(#{quote_column_name(k)} - #{basis[k]},2))/(2*POW(#{sigma[k]},2)))"
      end
    end

    def weight_normalizers
      max_exprs = basis.keys.map do |k|
        "MAX(#{qc(k, :w)}) AS #{qc(k, :w_max)}"
      end
      maxes = connection.select_one("SELECT #{max_exprs.join(', ')} FROM #{table_name}")
      basis.keys.map do |k|
        "#{qc(k, :n_w)} = #{qc(k, :w)} / #{maxes[c(k, :w_max)]}"
      end
    end

    def sigma
      @sigma ||= begin
        exprs = basis.map do |column_name, kernel_value|
          sql = "#{config.sigma} AS #{qc(column_name)}"
          sql.gsub! ':column', quote_column_name(column_name)
          sql.gsub! ':value', kernel_value.to_f.to_s
          sql
        end
        row = connection.select_one(%{SELECT #{exprs.join(', ')} FROM #{kernel.class.quoted_table_name} WHERE #{all_targets_not_null_condition} AND #{basis_not_null_condition}})
        basis.inject({}) do |memo, (column_name, _)|
          memo[column_name] = row[c(column_name)].to_f
          memo
        end
      end
    end

    def randomness
      @randomness ||= [Time.now.strftime('%H%M%S'), Kernel.rand(1e5)].join('_')
    end

    def table_name
      @table_name ||= "fuzzy_infer_#{randomness}"
    end

    def additional_column_definitions
      cols = []
      cols << "ADD COLUMN #{qc(:fuzzy_membership)} FLOAT DEFAULT NULL"
      basis.keys.each do |k|
        cols << "ADD COLUMN #{qc(k, :w)} FLOAT DEFAULT NULL"
        cols << "ADD COLUMN #{qc(k, :n_w)} FLOAT DEFAULT NULL"
      end
      targets.each do |target|
        cols << "ADD COLUMN #{qc(target, :v)} FLOAT DEFAULT NULL"
      end
      cols
    end

    def basis_not_null_condition
      basis.keys.map do |basis|
        "#{quote_column_name(basis)} IS NOT NULL"
      end.join ' AND '
    end

    def all_targets_not_null_condition
      [config.target].flatten.map do |target|
        "#{quote_column_name(target)} IS NOT NULL"
      end.join ' AND '
    end

    def connection
      kernel.connection
    end

    # quoted version of #c
    def qc(column_name, suffix = nil)
      quote_column_name c(column_name, suffix)
    end

    # column name that won't step on anybody's toes
    def c(column_name, suffix = nil)
      [column_name, suffix, randomness].compact.join '_'
    end
  end
end

