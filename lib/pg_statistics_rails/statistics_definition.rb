# frozen_string_literal: true

module PgStatisticsRails
  StatisticsDefinition = Struct.new(:table_name, :name, :columns, :kinds)
end
