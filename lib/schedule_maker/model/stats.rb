# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  module Model
    # A ScheduleMaker::Model::Stats object is used to render ERB templates
    class Stats
      # Constructor
      # @param schedule [ScheduleMaker::Schedule] Schedule object to render stats for
      def initialize(schedule)
        @sked = schedule.as_schedule(schedule.start)
        @stats = schedule.stats
        @valid_shift_lengths = schedule.rotation.participants.values.map { |x| x[:period_length] }.uniq.sort
        lcm = @valid_shift_lengths.reduce(:lcm)
        @target_spacings = Hash[@valid_shift_lengths.map { |k| [k, (@sked.size * k) / (lcm * schedule.rotation.count)] }]
      end

      # Needed to make ERB work
      def getbinding
        binding
      end

      # Helper function to format percentages within ERB
      def self.percentage(numerator, denominator)
        return '0.00%' if denominator == 0
        format('%0.2f%%', numerator * 100.0 / (denominator * 1.0))
      end
    end
  end
end
