# Changelog

## 0.2.0 (2026-10-24)

- Statistics targets: `create_statistics` takes `target:`, and `set_column_statistics_target` / `set_index_statistics_target` set column and expression-index targets. All three are read back by `statistics` / `statistics_targets` and dumped into `db/schema.rb` after each table.
- Column and index targets for a whole dump come from one catalog query per schema.

## 0.1.0 (2026-10-23)

- Initial release extracted from [rails/rails#59317](https://github.com/rails/rails/pull/59317):
  - `create_statistics` and `drop_statistics` migration methods on the PostgreSQL adapter
  - Reversible migration support via `ActiveRecord::Migration::CommandRecorder`
  - `statistics` introspection on `PostgreSQLAdapter`
  - `db/schema.rb` dumping support via `PostgreSQL::SchemaDumper`
