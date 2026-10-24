# frozen_string_literal: true

require "active_support"
require_relative "pg_statistics_rails/version"
require_relative "pg_statistics_rails/statistics_definition"
require_relative "pg_statistics_rails/schema_statements"
require_relative "pg_statistics_rails/schema_dumper"
require_relative "pg_statistics_rails/command_recorder"

ActiveSupport.on_load(:active_record) do
  require "active_record/migration/command_recorder"
  ActiveRecord::Migration::CommandRecorder.include(PgStatisticsRails::CommandRecorder)
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  unless ActiveRecord::ConnectionAdapters::PostgreSQL.const_defined?(:StatisticsDefinition)
    ActiveRecord::ConnectionAdapters::PostgreSQL.const_set(
      :StatisticsDefinition,
      PgStatisticsRails::StatisticsDefinition
    )
  end

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(PgStatisticsRails::SchemaStatements)
  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(PgStatisticsRails::SchemaDumper)
end
