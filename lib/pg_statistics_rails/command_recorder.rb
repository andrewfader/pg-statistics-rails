# frozen_string_literal: true

module PgStatisticsRails
  module CommandRecorder
    def self.included(recorder_class)
      if recorder_class.const_defined?(:ReversibleAndIrreversibleMethods) &&
         !recorder_class::ReversibleAndIrreversibleMethods.frozen? &&
         !recorder_class::ReversibleAndIrreversibleMethods.include?(:create_statistics)
        recorder_class::ReversibleAndIrreversibleMethods.push(:create_statistics, :drop_statistics, :set_column_statistics_target, :set_index_statistics_target)
      end

      if recorder_class.private_instance_methods.include?(:inverse_of) &&
         recorder_class.instance_method(:inverse_of).arity == 3
        recorder_class.include(KwargsRecorder)
      else
        recorder_class.include(LegacyArgsRecorder)
      end
    end

    def self.invert_statistics_target(command, args, changes)
      unless changes.is_a?(Hash) && changes.key?(:from) && changes.key?(:to)
        raise ActiveRecord::IrreversibleMigration, "#{command} is only reversible if given a :from and :to option."
      end

      [command, [*args.first(2), { from: changes[:to], to: changes[:from] }]]
    end

    module KwargsRecorder
      def create_statistics(*args, **kwargs, &block)
        record(:create_statistics, args, kwargs, &block)
      end

      def drop_statistics(*args, **kwargs, &block)
        record(:drop_statistics, args, kwargs, &block)
      end

      def set_column_statistics_target(*args, **kwargs, &block)
        record(:set_column_statistics_target, args, kwargs, &block)
      end

      def set_index_statistics_target(*args, **kwargs, &block)
        record(:set_index_statistics_target, args, kwargs, &block)
      end

      private
        def invert_create_statistics(args, kwargs, &block)
          kwargs = kwargs.dup
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          [:drop_statistics, args, kwargs, block]
        end

        def invert_drop_statistics(args, kwargs, &block)
          _table, columns = args
          raise ActiveRecord::IrreversibleMigration, "drop_statistics is only reversible if given columns." if columns.blank?

          kwargs = kwargs.dup
          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)
          [:create_statistics, args, kwargs, block]
        end

        def invert_set_column_statistics_target(args, kwargs, &block)
          [*CommandRecorder.invert_statistics_target(:set_column_statistics_target, args, args[2] || kwargs), {}, block]
        end

        def invert_set_index_statistics_target(args, kwargs, &block)
          [*CommandRecorder.invert_statistics_target(:set_index_statistics_target, args, args[2] || kwargs), {}, block]
        end
    end

    module LegacyArgsRecorder
      ruby2_keywords def create_statistics(*args, &block)
        record(:create_statistics, args, &block)
      end

      ruby2_keywords def drop_statistics(*args, &block)
        record(:drop_statistics, args, &block)
      end

      ruby2_keywords def set_column_statistics_target(*args, &block)
        record(:set_column_statistics_target, args, &block)
      end

      ruby2_keywords def set_index_statistics_target(*args, &block)
        record(:set_index_statistics_target, args, &block)
      end

      private
        def invert_create_statistics(args, &block)
          if (options = args.last).is_a?(Hash)
            options[:if_exists] = options.delete(:if_not_exists) if options.key?(:if_not_exists)
          end
          [:drop_statistics, args, block]
        end

        def invert_drop_statistics(args, &block)
          _table, columns = args.dup.tap(&:extract_options!)
          raise ActiveRecord::IrreversibleMigration, "drop_statistics is only reversible if given columns." if columns.blank?

          if (options = args.last).is_a?(Hash)
            options[:if_not_exists] = options.delete(:if_exists) if options.key?(:if_exists)
          end
          [:create_statistics, args, block]
        end

        def invert_set_column_statistics_target(args, &block)
          [*CommandRecorder.invert_statistics_target(:set_column_statistics_target, args, args[2]), block]
        end

        def invert_set_index_statistics_target(args, &block)
          [*CommandRecorder.invert_statistics_target(:set_index_statistics_target, args, args[2]), block]
        end
    end
  end
end
