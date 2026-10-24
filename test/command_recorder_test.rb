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
end
