# Changelog

## 0.3.0 (Unreleased)

- `create_statistics` analyzes the table right after creating the object, so the planner uses it before autovacuum next analyzes the table. The `ANALYZE` covers the plain columns of every statistics object on the table, which builds their expressions too, or the whole table when they have only expressions. `if_not_exists: true` skips it when the object already exists. `analyze: false` skips it. On PostgreSQL 18+ a partitioned table gets `ANALYZE ONLY`, leaving its partitions alone.
- `set_column_statistics_target` and `set_index_statistics_target` take `from:` and `to:`, which makes them reversible in `change`. Given a bare target, rolling them back raises `ActiveRecord::IrreversibleMigration` instead of applying the target again. A `from:` without `to:`, or the reverse, raises `ArgumentError`.

## 0.2.1 (Unreleased)

- Package every file world-readable. 0.2.0 shipped four files under `lib/` with mode 0640, so Ruby running as any user other than the one that installed the gem cannot load it. `rake build` and `rake release` now stop when a packaged file is not world-readable.

## 0.2.0 (2026-10-24)

- Statistics targets: `create_statistics` takes `target:`, and `set_column_statistics_target` / `set_index_statistics_target` set column and expression-index targets. All three are read back by `statistics` / `statistics_targets` and dumped into `db/schema.rb` after each table.
- Column and index targets for a whole dump come from one catalog query per schema.

## 0.1.0 (2026-10-23)

- Initial release extracted from [rails/rails#59317](https://github.com/rails/rails/pull/59317):
  - `create_statistics` and `drop_statistics` migration methods on the PostgreSQL adapter
  - Reversible migration support via `ActiveRecord::Migration::CommandRecorder`
  - `statistics` introspection on `PostgreSQLAdapter`
  - `db/schema.rb` dumping support via `PostgreSQL::SchemaDumper`
