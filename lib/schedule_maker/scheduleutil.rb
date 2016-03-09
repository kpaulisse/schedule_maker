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
      offset = options.fetch(:offset, '+00:00')
      day_length = options.fetch(:day_length, 86400.0)
      prev_rotation = ScheduleMaker::RotationUtil.build_prev_rotation_hash(options.fetch(:prev_rotation, []))
      prev_rotation_timestamped = build_timestamped_prev_rotation_hash(prev_rotation, start, shift_length, day_length)
      result = if options.fetch(:consolidated, false)
                 to_schedule_consolidated(start, rotation, shift_length, offset, prev_rotation_timestamped, day_length)
               else
                 to_schedule_not_consolidated(start, rotation, shift_length, offset, prev_rotation_timestamped, day_length)
               end
      if options.key?(:participants)
        result.each do |item|
          timezone = options[:participants][item[:assignee]].fetch(:timezone, 'UTC')
          local_start = ScheduleMaker::Util.dateparse(item[:start], timezone)
          item[:local_start] = local_start.strftime('%A %Y-%m-%d %H:%M:%S')
          local_end = ScheduleMaker::Util.dateparse(item[:end], timezone)
          item[:local_end] = local_end.strftime('%A %Y-%m-%d %H:%M:%S')
        end
      end
      result
    end

    # Build a schedule that lists out all shifts, not consolidated
    # Intended only to be called internally by to_schedule method above.
    def self.to_schedule_not_consolidated(start, rotation, shift_length, offset, prev, day_length)
      result = []
      rotation.each do |period|
        period.period_length.times do
          hsh = {}
          hsh[:start] = start.strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          hsh[:end] = (start + shift_length * day_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          hsh[:assignee] = period.participant
          hsh[:length] = period.period_length
          if prev.key?(period.participant)
            diff = start.to_i - prev[period.participant]
            hsh[:prev] = (diff * 1.0) / day_length
          end
          result << hsh
          start += shift_length * day_length
        end
        prev[period.participant] = start.to_i
      end
      result
    end

    # Build a schedule that consolidates consecutive shifts belonging to the same assignee
    # Intended only to be called internally by to_schedule method above.
    def self.to_schedule_consolidated(start, rotation, shift_length, offset, prev, day_length)
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
          prev[buffer[:assignee]] = start.to_i
          buffer = {
            assignee: period.participant,
            start: start.strftime("%Y-%m-%dT%H:%M:%S#{offset}"),
          end: (start + period.period_length * shift_length * day_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}"),
            length: period.period_length
          }
          buffer[:prev] = (start.to_i - prev[period.participant]) * 1.0 / day_length if prev.key?(period.participant)
        else
          buffer[:end] = (start + period.period_length * shift_length * day_length).strftime("%Y-%m-%dT%H:%M:%S#{offset}")
          buffer[:length] += period.period_length
        end
        start += period.period_length * shift_length * day_length
      end
      result
    end

    # Convert previous rotation (with offset days) into previous rotation with offset timestamps.
    # Intended only to be called internally by to_schedule method above.
    def self.build_timestamped_prev_rotation_hash(hash_in, start, shift_length, day_length = 86400.0)
      return hash_in if hash_in.empty?
      result = {}
      hash_in.keys.each do |key|
        result[key] = start.to_i - ((hash_in[key] - 1) * shift_length * day_length)
      end
      result
    end
  end
end
