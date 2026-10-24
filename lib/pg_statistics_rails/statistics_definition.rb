# frozen_string_literal: true

module PgStatisticsRails
  # `target` is the object's explicit statistics target, or nil for the default.
  StatisticsDefinition = Struct.new(:table_name, :name, :columns, :kinds, :target)

  # Explicit `SET STATISTICS` targets on a table's columns and on its indexes'
  # expression columns. `columns` maps a column name to its target; `indexes`
  # holds `[index_name, column_number, target]`.
  StatisticsTargets = Struct.new(:columns, :indexes) do
    def empty?
      columns.empty? && indexes.empty?
    end
  end
end
