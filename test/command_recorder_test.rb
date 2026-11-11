# frozen_string_literal: true

require "test_helper"

class CommandRecorderTest < Minitest::Test
  def setup
    @recorder = ActiveRecord::Migration::CommandRecorder.new
  end

  def test_invert_create_statistics
    @recorder.revert do
      @recorder.create_statistics(:addresses, [:city, :zip_code], name: "city_zip_stat", if_not_exists: true)
    end

    cmd = @recorder.commands.first
    if cmd.size == 4
      assert_equal [:drop_statistics, [:addresses, [:city, :zip_code]], { name: "city_zip_stat", if_exists: true }, nil], cmd
    else
      assert_equal [:drop_statistics, [:addresses, [:city, :zip_code], { name: "city_zip_stat", if_exists: true }], nil], cmd
    end
  end

  def test_invert_drop_statistics
    @recorder.revert do
      @recorder.drop_statistics(:addresses, [:city, :zip_code], kinds: [:mcv], if_exists: true)
    end

    cmd = @recorder.commands.first
    if cmd.size == 4
      assert_equal [:create_statistics, [:addresses, [:city, :zip_code]], { kinds: [:mcv], if_not_exists: true }, nil], cmd
    else
      assert_equal [:create_statistics, [:addresses, [:city, :zip_code], { kinds: [:mcv], if_not_exists: true }], nil], cmd
    end
  end

  def test_invert_drop_statistics_without_columns
    assert_raises(ActiveRecord::IrreversibleMigration) do
      @recorder.revert do
        @recorder.drop_statistics(:addresses, name: "city_zip_stat")
      end
    end
  end

  def test_invert_set_column_statistics_target
    @recorder.revert do
      @recorder.set_column_statistics_target(:addresses, :city, from: nil, to: 1000)
    end

    cmd = @recorder.commands.first
    if cmd.size == 4
      assert_equal [:set_column_statistics_target, [:addresses, :city, { from: 1000, to: nil }], {}, nil], cmd
    else
      assert_equal [:set_column_statistics_target, [:addresses, :city, { from: 1000, to: nil }], nil], cmd
    end
  end

  def test_invert_set_column_statistics_target_without_from
    assert_raises(ActiveRecord::IrreversibleMigration) do
      @recorder.revert do
        @recorder.set_column_statistics_target(:addresses, :city, 1000)
      end
    end
  end

  def test_invert_set_index_statistics_target
    @recorder.revert do
      @recorder.set_index_statistics_target("index_addresses_on_lower_city", 1, from: 200, to: 1000)
    end

    cmd = @recorder.commands.first
    if cmd.size == 4
      assert_equal [:set_index_statistics_target, ["index_addresses_on_lower_city", 1, { from: 1000, to: 200 }], {}, nil], cmd
    else
      assert_equal [:set_index_statistics_target, ["index_addresses_on_lower_city", 1, { from: 1000, to: 200 }], nil], cmd
    end
  end

  def test_invert_set_index_statistics_target_without_from
    assert_raises(ActiveRecord::IrreversibleMigration) do
      @recorder.revert do
        @recorder.set_index_statistics_target("index_addresses_on_lower_city", 1, 1000)
      end
    end
  end
end
