# frozen_string_literal: true

require "digest/sha2"

module PgStatisticsRails
  module SchemaStatements
    # Returns an array of extended statistics objects for the given table, or a
    # Hash of them keyed by table name when given an Array of tables.
    # The statistics are represented as StatisticsDefinition objects.
    def statistics(table_name)
      result = fetch_statistics(Array(table_name).map(&:to_s))
      table_name.is_a?(Array) ? result : result[table_name.to_s]
    end

    # Creates an extended statistics object, which lets the planner estimate
    # how the given columns and expressions depend on each other.
    #
    # ```
    # create_statistics :addresses, [:city, :zip_code], kinds: [:dependencies], name: "addresses_city_zip_code_stat"
    # ```
    #
    # generates:
    #
    # ```
    # CREATE STATISTICS "addresses_city_zip_code_stat" (dependencies) ON "city", "zip_code" FROM "addresses"
    # ```
    #
    # A string that is not a plain column name is treated as an expression:
    #
    # ```
    # create_statistics :users, ["lower(email)"], name: "users_lower_email_stat"
    # ```
    #
    # The `options` hash can include the following keys:
    #
    # `:name`
    # :   The statistics name. Defaults to `stat_rails_<identifier>`.
    #
    # `:kinds`
    # :   The statistics kinds to build: any of `:ndistinct`, `:dependencies`, and `:mcv`.
    #     Defaults to every kind the server supports.
    #
    # `:if_not_exists`
    # :   Silently ignore if the statistics object already exists.
    #
    # Statistics are built by the next `ANALYZE` of the table.
    def create_statistics(table_name, columns, **options)
      name = statistics_name(table_name, columns: columns, **options)
      kinds = Array(options[:kinds])

      sql = +"CREATE STATISTICS"
      sql << " IF NOT EXISTS" if options[:if_not_exists]
      sql << " #{quote_table_name(name)}"
      sql << " (#{kinds.map(&:to_s).join(', ')})" if kinds.any?
      sql << " ON #{quoted_statistics_columns(columns)} FROM #{quote_table_name(table_name)}"

      execute sql
    end

    # Drops the given extended statistics object.
    #
    # ```
    # drop_statistics :addresses, name: "addresses_city_zip_code_stat"
    # ```
    #
    # The `columns` parameter will be ignored if present. It can be helpful
    # to provide it, with the same options, in a migration's `change` method
    # so it can be reverted. In that case, they will be used by #create_statistics.
    def drop_statistics(table_name, columns = nil, **options)
      name = statistics_name(table_name, columns: columns, **options)

      execute "DROP STATISTICS#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(name)}"
    end

    private
      # Columns are stored ordered by attribute number, ahead of any expressions,
      # whatever order they were created in.
      def fetch_statistics(tables)
        return {} if tables.empty?

        expressions = database_version >= 14_00_00 ? "pg_get_statisticsobjdef_expressions(s.oid)" : "NULL"

        fetch_statistics_by_schema(tables) do |schema, group|
          quoted_names = group.map { |table| quote(extract_schema_qualified_name(table).last) }.join(", ")
          sql = <<~SQL
            WITH tables AS (
              SELECT DISTINCT ON (c.relname) c.oid, c.relname, c.relkind
              FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = #{schema}
                AND c.relname IN (#{quoted_names})
              ORDER BY c.relname, array_position(current_schemas(false), n.nspname)
            )
            SELECT t.relname AS table_name, s.stxname, sn.nspname, sn.nspname = #{schema} AS same_schema, s.stxkind,
              (
                SELECT array_agg(a.attname ORDER BY a.attnum)
                FROM pg_attribute a
                WHERE a.attrelid = t.oid AND a.attnum = ANY (s.stxkeys)
              ) AS columns,
              #{expressions} AS expressions
            FROM pg_statistic_ext s
            JOIN tables t ON s.stxrelid = t.oid
            JOIN pg_namespace sn ON sn.oid = s.stxnamespace
            ORDER BY s.stxname
          SQL

          rows = if respond_to?(:query_all, true)
            query_all(sql, "SCHEMA")
          else
            internal_exec_query(sql, "SCHEMA", allow_retry: true, materialize_transactions: false).to_a
          end
          by_name = rows.group_by { |row| row["table_name"] }

          group.index_with do |table|
            bare_name = extract_schema_qualified_name(table).last
            build_statistics(table, by_name[bare_name] || [])
          end
        end
      end

      def fetch_statistics_by_schema(tables, &block)
        if respond_to?(:fetch_by_schema, true)
          fetch_by_schema(tables, &block)
        else
          tables.group_by { |table| extract_schema_qualified_name(table).first }.each_with_object({}) do |(schema_name, group), result|
            schema = schema_name ? quote(schema_name) : "ANY (current_schemas(false))"
            result.merge!(yield(schema, group))
          end
        end
      end

      def build_statistics(table_name, rows)
        rows.map do |row|
          name = row["same_schema"] ? row["stxname"] : "#{row['nspname']}.#{row['stxname']}"
          columns = [row["columns"], row["expressions"]].compact.flat_map { |list| decode_statistics_string_array(list) }
          kinds = decode_statistics_string_array(row["stxkind"]).filter_map { |kind| { "d" => :ndistinct, "f" => :dependencies, "m" => :mcv }[kind] }

          StatisticsDefinition.new(table_name, name, columns, kinds)
        end
      end

      def decode_statistics_string_array(value)
        if respond_to?(:decode_string_array, true)
          decode_string_array(value)
        else
          PG::TextDecoder::Array.new.decode(value)
        end
      end

      # An unqualified name is created in the first schema on the search path,
      # not the table's, so it takes the table's schema when the table names one.
      def statistics_name(table_name, columns: nil, **options)
        options.fetch(:name) do
          raise ArgumentError, "Statistics require a name or columns" if columns.blank?

          identifier = "#{table_name}_#{Array(columns).map(&:to_s) * '_and_'}_stat"
          "stat_rails_#{Digest::SHA256.hexdigest(identifier).first(10)}"
        end.then do |name|
          schema, = extract_schema_qualified_name(table_name.to_s)
          schema && !name.to_s.include?(".") ? "#{schema}.#{name}" : name
        end
      end

      def quoted_statistics_columns(columns)
        Array(columns).map do |column|
          column = column.to_s
          column.match?(/\A\w+\z/) ? quote_column_name(column) : "(#{column})"
        end.join(", ")
      end
  end
end
