# frozen_string_literal: true

module PgStatisticsRails
  module SchemaDumper
    private
      def read_schema_metadata(tables)
        super
        @statistics = @connection.statistics(tables)
      end

      def table(table, stream)
        super
        statistics(table, stream)
      end

      # After the table, since a definition names the columns it covers.
      def statistics(table, stream)
        table_statistics = defined?(@statistics) && @statistics ? @statistics[table] : @connection.statistics(table)
        if table_statistics&.any?
          stream.puts
          table_name = remove_prefix_and_suffix(table)
          table_name = relation_name(table_name) if respond_to?(:relation_name, true)
          table_statistics.each do |statistic|
            parts = [ table_name.inspect, statistic.columns.inspect, "name: #{statistic.name.inspect}" ]
            parts << "kinds: #{statistic.kinds.inspect}" unless statistic.kinds.empty? || statistic.kinds == [:ndistinct, :dependencies, :mcv]

            stream.puts "  create_statistics #{parts.join(', ')}"
          end
        end
      end
  end
end
