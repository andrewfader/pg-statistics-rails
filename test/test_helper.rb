# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "active_record"
require "pg-statistics-rails"

db_config = {
  adapter: "postgresql",
  database: ENV.fetch("PGDATABASE", "pg_statistics_rails_test")
}
db_config[:host] = ENV["PGHOST"] if ENV["PGHOST"]
db_config[:port] = ENV["PGPORT"] if ENV["PGPORT"]
db_config[:username] = ENV["PGUSER"] if ENV["PGUSER"]
db_config[:password] = ENV["PGPASSWORD"] if ENV["PGPASSWORD"]

begin
  ActiveRecord::Base.establish_connection(db_config)
  ActiveRecord::Base.lease_connection.execute("SELECT 1")
rescue ActiveRecord::NoDatabaseError
  ActiveRecord::Base.establish_connection(db_config.merge(database: "postgres"))
  ActiveRecord::Base.lease_connection.create_database(db_config[:database])
  ActiveRecord::Base.establish_connection(db_config)
end
