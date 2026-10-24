# Changelog

## 0.1.0 (2026-10-23)

- Initial release extracted from [rails/rails#59317](https://github.com/rails/rails/pull/59317):
  - `create_statistics` and `drop_statistics` migration methods on the PostgreSQL adapter
  - Reversible migration support via `ActiveRecord::Migration::CommandRecorder`
  - `statistics` introspection on `PostgreSQLAdapter`
  - `db/schema.rb` dumping support via `PostgreSQL::SchemaDumper`
