# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # Create statistics for a rotation
  class Stats
    # Calculate statistics about a rotation, including total days, total shifts,
    # shift length, and spacing.
    # @param schedule [ScheduleMaker::Schedule] Computed schedule
    # @param start [DateTime] Start date/time for schedule
    def self.stats(schedule, start)
      stats = {}
      last_assignee = nil
      counter = 0
      sked = schedule.as_schedule(start)
      sked.each do |obj|
        stats[obj[:assignee]] ||= { days: 0, shifts: 0, spacing: [], min_shift: nil, max_shift: nil }
        stats[obj[:assignee]][:days] += 1
        stats[obj[:assignee]][:shifts] += 1 if last_assignee != obj[:assignee]
        stats[obj[:assignee]][:spacing] << obj[:prev].to_i if obj.key?(:prev) && obj[:assignee] != last_assignee
        if stats[obj[:assignee]][:min_shift].nil? || obj[:length] < stats[obj[:assignee]][:min_shift]
          stats[obj[:assignee]][:min_shift] = obj[:length]
        end
        if stats[obj[:assignee]][:max_shift].nil? || obj[:length] > stats[obj[:assignee]][:max_shift]
          stats[obj[:assignee]][:max_shift] = obj[:length]
        end
        last_assignee = obj[:assignee]
        counter += 1
      end
      stats
    end
  end
end
