# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # Some static methods that are useful when dealing with schedules.
  class ScheduleUtil
    # Format rotation as a schedule, starting at a certain date
    # @param start_date [String] Start date yyyy-mm-ddThh:mm:ss
    # @param rotation [Array<Period>] Rotation array
    # @param options
    #   - :shift_length [Numeric] Length of shift in days
    #   - :consolidated [Boolean] True to consolidate multiple shifts into one
    #   - :offset [String] +##:##, -##:## => Add this to all times
    #   - :prev_rotation [Array<Period>] Previous rotation, for calculating more spacings
    # @return [Array<Hash<:start,:end,:assignee,:length>>] Resulting schedule in order
    def self.to_schedule(start_date, rotation, options = {})
      start = ScheduleMaker::Util.dateparse(start_date)
      shift_length = options.fetch(:shift_length, 1)
      consolidated = options.fetch(:consolidated, false)
      offset = options.fetch(:offset, '+00:00')
      prev_rotation = ScheduleMaker::RotationUtil.build_prev_rotation_hash(options.fetch(:prev_rotation, []))
      prev_rotation_timestamped = build_timestamped_prev_rotation_hash(prev_rotation, start, shift_length)
      return to_schedule_consolidated(start, rotation, shift_length, offset, prev_rotation_timestamped) if consolidated
      to_schedule_not_consolidated(start, rotation, shift_length, offset, prev_rotation_timestamped)
    end

    # Build a schedule that lists out all shifts, not consolidated
    def self.to_schedule_not_consolidated(start, rotation, shift_length, offset, prev = {})
      result = []
      rotation.each do |period|
        period.period_length.times do
          hsh = {}
          hsh[:start] = start.strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          hsh[:end] = (start + shift_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          hsh[:assignee] = period.participant
          hsh[:length] = period.period_length
          hsh[:prev] = (start.to_time.to_i - prev[period.participant]) / (24.0 * 60 * 60) if prev.key?(period.participant)
          result << hsh
          start += shift_length
        end
        prev[period.participant] = start.to_time.to_i
      end
      result
    end

    # Build a schedule that consolidates consecutive shifts belonging to the same assignee
    def self.to_schedule_consolidated(start, rotation, shift_length, offset, prev = {})
      result = []
      rotation_copy = rotation.dup
      rotation_copy << false # Fake last element to trigger appending to result
      buffer = { assignee: nil }
      until rotation_copy.empty?
        period = rotation_copy.shift
        if period.is_a?(FalseClass) || period.participant != buffer[:assignee]
          result << buffer unless buffer[:assignee].nil?
          if period.is_a?(FalseClass)
            buffer = { assignee: nil }
            next
          end
          prev[buffer[:assignee]] = start.to_time.to_i
          buffer = {
            assignee: period.participant,
            start: start.strftime("%Y-%m-%dT%H:%M:%S#{offset}"),
            end: (start + period.period_length * shift_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}"),
            length: period.period_length
          }
          buffer[:prev] = (start.to_time.to_i - prev[period.participant]) / (24.0 * 60 * 60) if prev.key?(period.participant)
        else
          buffer[:end] = (start + period.period_length * shift_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          buffer[:length] += period.period_length
        end
        start += period.period_length * shift_length
      end
      result
    end

    def self.build_timestamped_prev_rotation_hash(hash_in, start, shift_length)
      return hash_in if hash_in.empty?
      result = {}
      hash_in.keys.each do |key|
        result[key] = start.to_time.to_i - ((hash_in[key] - 1) * shift_length * (24.0 * 60 * 60))
      end
      result
    end
  end
end
