# frozen_string_literal: true

require "test_helper"
require "stringio"

class PostgresqlStatisticsTargetsTest < Minitest::Test
  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :addresses, force: true do |t|
      t.string :city
      t.string :zip_code
      t.string :email
      t.index "lower(city)", name: "index_addresses_on_lower_city"
    end
  end

  def teardown
    @connection.drop_table :addresses, if_exists: true
    @connection.drop_schema "test_targets_schema", if_exists: true
  end

  def test_create_statistics_with_a_target
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", target: 900

    assert_equal 900, @connection.statistics("addresses").sole.target
  end

  def test_statistics_without_a_target_report_none
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat"

    assert_nil @connection.statistics("addresses").sole.target
  end

  def test_column_and_index_statistics_targets
    @connection.set_column_statistics_target :addresses, :city, 700
    @connection.set_index_statistics_target "index_addresses_on_lower_city", 1, 800

    targets = @connection.statistics_targets("addresses")
    assert_equal({ "city" => 700 }, targets.columns)
    assert_equal [["index_addresses_on_lower_city", 1, 800]], targets.indexes

    @connection.set_column_statistics_target :addresses, :city, nil
    @connection.set_index_statistics_target "index_addresses_on_lower_city", 1, nil
    assert_predicate @connection.statistics_targets("addresses"), :empty?
  end

  def test_schema_dump_writes_targets_after_the_table
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", target: 900
    @connection.set_column_statistics_target :addresses, :city, 700
    @connection.set_index_statistics_target "index_addresses_on_lower_city", 1, 800

    output = dump_table_schema("addresses")
    assert_match %r{create_table "addresses".*?^  end\n\n  create_statistics "addresses", \["city", "zip_code"\], name: "addresses_city_zip_code_stat", target: 900\n  set_column_statistics_target "addresses", "city", 700\n  set_index_statistics_target "index_addresses_on_lower_city", 1, 800\n}m, output
  end

  def test_schema_dump_leaves_out_a_table_with_no_statistics_or_targets
    refute_match(/create_statistics|statistics_target/, dump_table_schema("addresses"))
  end

  # Postgres's own definition of each object is the reference, so a round trip
  # through the dump must reproduce it exactly, including quoting and targets.
  def test_schema_dump_round_trips_unusual_definitions
    @connection.create_statistics :addresses, [:city, :zip_code], name: "Addresses City Zip", kinds: [:ndistinct], target: 250
    @connection.create_statistics :addresses, [:zip_code, :email], name: "addresses_zip_email_mcv", kinds: [:mcv]
    if @connection.database_version >= 14_00_00
      @connection.create_statistics :addresses, ["lower(email)"], name: "addresses_lower_email_stat"
      @connection.create_statistics :addresses, [:city, "(zip_code || '-' || lower(city))"], name: "addresses_city_zip_city_stat", kinds: [:dependencies, :mcv]
    end
    @connection.set_column_statistics_target :addresses, :email, 1000
    @connection.set_index_statistics_target "index_addresses_on_lower_city", 1, 600

    before = catalog_snapshot("addresses")
    statements = dump_table_schema("addresses").lines.grep(/create_statistics|statistics_target/)

    @connection.statistics("addresses").each { |statistic| @connection.drop_statistics :addresses, name: statistic.name }
    @connection.set_column_statistics_target :addresses, :email, nil
    @connection.set_index_statistics_target "index_addresses_on_lower_city", 1, nil
    assert_empty catalog_snapshot("addresses").values_at(:statistics, :column_targets, :index_targets).flatten

    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define { statements.each { |statement| eval(statement) } }
    end

    assert_equal before, catalog_snapshot("addresses")
  end

  def test_schema_dump_round_trips_targets_on_a_schema_qualified_table
    @connection.create_schema "test_targets_schema"
    @connection.create_table "test_targets_schema.addresses" do |t|
      t.string :city
      t.string :zip_code
      t.index "lower(city)", name: "index_schema_addresses_on_lower_city"
    end
    @connection.create_statistics "test_targets_schema.addresses", [:city, :zip_code], name: "schema_addresses_stat", target: 300
    @connection.set_column_statistics_target "test_targets_schema.addresses", :city, 400
    @connection.set_index_statistics_target "test_targets_schema.index_schema_addresses_on_lower_city", 1, 500

    targets = @connection.statistics_targets("test_targets_schema.addresses")
    assert_equal({ "city" => 400 }, targets.columns)
    assert_equal [["test_targets_schema.index_schema_addresses_on_lower_city", 1, 500]], targets.indexes
    assert_equal 300, @connection.statistics("test_targets_schema.addresses").sole.target
    assert_predicate @connection.statistics_targets("addresses"), :empty?
  end

  private
    def catalog_snapshot(table)
      {
        statistics: @connection.select_rows(<<~SQL),
          SELECT pg_get_statisticsobjdef(s.oid), NULLIF(GREATEST(COALESCE(s.stxstattarget::int, -1), -1), -1)
          FROM pg_statistic_ext s JOIN pg_class c ON c.oid = s.stxrelid
          WHERE c.relname = '#{table}' ORDER BY s.stxname
        SQL
        column_targets: @connection.select_rows(<<~SQL),
          SELECT a.attname, a.attstattarget FROM pg_attribute a
          WHERE a.attrelid = '#{table}'::regclass AND a.attnum > 0 AND a.attstattarget >= 0 ORDER BY a.attnum
        SQL
        index_targets: @connection.select_rows(<<~SQL)
          SELECT ic.relname, a.attnum, a.attstattarget FROM pg_index i
          JOIN pg_class ic ON ic.oid = i.indexrelid JOIN pg_attribute a ON a.attrelid = ic.oid
          WHERE i.indrelid = '#{table}'::regclass AND a.attstattarget >= 0 ORDER BY ic.relname, a.attnum
        SQL
      }
    end

    def dump_table_schema(*tables)
      old_ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
      ActiveRecord::SchemaDumper.ignore_tables = @connection.data_sources - tables
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(@connection.pool, stream)
      stream.string
    ensure
      ActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
    end
end
