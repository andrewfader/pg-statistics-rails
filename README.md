# pg-statistics-rails

PostgreSQL extended statistics (`CREATE STATISTICS`) support for Active Record migrations and `db/schema.rb`.

PostgreSQL extended statistics let the query planner estimate how columns and expressions depend on each other, fixing row estimates where the column-independence assumption breaks down. Without schema dumper support, statistics created via `execute` only exist in databases that ran that migration — any database built via `db:schema:load` (test databases, CI, fresh environments) plans queries without them.

`pg-statistics-rails` adds:

- `create_statistics` and `drop_statistics` migration helpers (reversible via `CommandRecorder`)
- `connection.statistics(table_name)` introspection reading `pg_statistic_ext`
- Automatic `create_statistics` dumping in `db/schema.rb` after each table's `create_table` block

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
#      kinds=[:dependencies]>]
```

## License

Released under the [MIT License](LICENSE.txt).
