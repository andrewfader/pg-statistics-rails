# pg-statistics-rails

[![CI](https://github.com/andrewfader/pg-statistics-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewfader/pg-statistics-rails/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/andrewfader/pg-statistics-rails/graph/badge.svg)](https://codecov.io/gh/andrewfader/pg-statistics-rails)
[![Gem Version](https://badge.fury.io/rb/pg-statistics-rails.svg)](https://rubygems.org/gems/pg-statistics-rails)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.txt)

PostgreSQL extended statistics (`CREATE STATISTICS`) support for Active Record migrations and `db/schema.rb`.

PostgreSQL extended statistics let the query planner estimate how columns and expressions depend on each other, fixing row estimates where the column-independence assumption breaks down. Without schema dumper support, statistics created via `execute` only exist in databases that ran that migration — any database built via `db:schema:load` (test databases, CI, fresh environments) plans queries without them.

`pg-statistics-rails` adds:

- `create_statistics` and `drop_statistics` migration helpers (reversible via `CommandRecorder`)
- `connection.statistics(table_name)` introspection reading `pg_statistic_ext`
- Statistics targets (`SET STATISTICS`) on statistics objects, columns, and expression index columns
- Automatic dumping of all of it in `db/schema.rb` after each table's `create_table` block

## Installation

Add to your `Gemfile`:

```ruby
gem "pg-statistics-rails"
```

## Usage

### Creating statistics in a migration

```ruby
class AddAddressStatistics < ActiveRecord::Migration[8.0]
  def change
    # Specific statistics kinds (:ndistinct, :dependencies, :mcv)
    create_statistics :addresses, [:city, :zip_code],
      kinds: [:dependencies],
      name: "addresses_city_zip_code_stat"

    # Default kinds (all supported by the server) and auto-generated stat_rails_<hash> name
    create_statistics :addresses, [:city, :state]

    # Expression statistics (PostgreSQL 14+)
    create_statistics :users, [:city, "lower(email)"],
      kinds: [:mcv],
      name: "users_city_lower_email_stat"
  end
end
```

Options:

- `:name` — Custom statistics object name. Defaults to `stat_rails_<10-char sha256>`. When the table name is schema-qualified and `:name` is not, the statistics object is created in the table's schema.
- `:kinds` — Array of kinds to build (`:ndistinct`, `:dependencies`, `:mcv`). Defaults to all kinds.
- `:if_not_exists` — Emits `CREATE STATISTICS IF NOT EXISTS`.
- `:target` — The object's statistics target (`ALTER STATISTICS ... SET STATISTICS`). Defaults to `default_statistics_target`.

### Statistics targets

A statistics target sets how much `ANALYZE` samples. Raise it for a column, or an expression index's column, whose estimates are off:

```ruby
set_column_statistics_target :addresses, :city, 1000
set_index_statistics_target "index_addresses_on_lower_city", 1, 1000 # column by position

# nil restores default_statistics_target
set_column_statistics_target :addresses, :city, nil
```

These are not reversible, since the previous target is not recorded; use `up`/`down`. Explicit targets are dumped after the table:

```ruby
create_statistics "addresses", ["city", "zip_code"], name: "addresses_city_zip_code_stat", target: 900
set_column_statistics_target "addresses", "city", 1000
set_index_statistics_target "index_addresses_on_lower_city", 1, 1000
```

### Dropping statistics

```ruby
# Reversible in `change` when columns are provided:
drop_statistics :addresses, [:city, :zip_code],
  kinds: [:dependencies],
  name: "addresses_city_zip_code_stat",
  if_exists: true

# Or by name alone in `up`/`down`:
drop_statistics :addresses, name: "addresses_city_zip_code_stat"
```

### Inspecting statistics

```ruby
ActiveRecord::Base.lease_connection.statistics(:addresses)
# => [#<struct PgStatisticsRails::StatisticsDefinition
#      table_name="addresses",
#      name="addresses_city_zip_code_stat",
#      columns=["city", "zip_code"],
#      kinds=[:dependencies],
#      target=nil>]

ActiveRecord::Base.lease_connection.statistics_targets(:addresses)
# => #<struct PgStatisticsRails::StatisticsTargets
#      columns={"city"=>1000},
#      indexes=[["index_addresses_on_lower_city", 1, 1000]]>
```

## License

Released under the [MIT License](LICENSE.txt).
