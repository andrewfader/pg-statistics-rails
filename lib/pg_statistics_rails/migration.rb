# frozen_string_literal: true

module PgStatisticsRails
  module Migration
    def exec_migration(connection, direction)
      return super unless connection.respond_to?(:analyzing_statistics_once)

      connection.analyzing_statistics_once { super }
    end
  end
end
