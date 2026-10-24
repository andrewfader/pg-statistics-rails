# frozen_string_literal: true

module PgStatisticsRails
  module SchemaDumper
    ALL_KINDS = [:ndistinct, :dependencies, :mcv].freeze

    private
      def read_schema_metadata(tables)
        super
        @statistics = @connection.statistics(tables)
        @statistics_targets = @connection.statistics_targets(tables)
      end

      def table(table, stream)
        super
        statistics(table, stream)
      end

      # After the table, since a definition names the columns and indexes it covers.
      def statistics(table, stream)
        table_statistics = defined?(@statistics) && @statistics ? @statistics[table] : @connection.statistics(table)
        targets = defined?(@statistics_targets) && @statistics_targets ? @statistics_targets[table] : @connection.statistics_targets(table)
        return if table_statistics.blank? && (targets.nil? || targets.empty?)

        stream.puts
        table_name = remove_prefix_and_suffix(table)
        table_name = relation_name(table_name) if respond_to?(:relation_name, true)

        Array(table_statistics).each do |statistic|
          parts = [table_name.inspect, statistic.columns.inspect, "name: #{statistic.name.inspect}"]
          parts << "kinds: #{statistic.kinds.inspect}" unless statistic.kinds.empty? || statistic.kinds == ALL_KINDS
          parts << "target: #{statistic.target}" unless statistic.target.nil?

          stream.puts "  create_statistics #{parts.join(', ')}"
        end

        return if targets.nil?

        targets.columns.each do |column, target|
          stream.puts "  set_column_statistics_target #{table_name.inspect}, #{column.inspect}, #{target}"
        end
        targets.indexes.each do |index, column_number, target|
          stream.puts "  set_index_statistics_target #{index.inspect}, #{column_number}, #{target}"
        end
      end
  end
end
