# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  class Rotation
    attr_reader :schedule, :participants, :rotation_length

    def initialize(participants, count = 1, prev_rotation = [], initial_schedule = nil)
      @participants = participants
      @period_lcm = @participants.values.reduce(:lcm)
      @rotation_length = @period_lcm * @participants.keys.size
      @target_spacing = @participants.keys.size - 1
      @participant_arrays = build_initial_participant_arrays

      if initial_schedule.nil?
        initial_schedule = build_initial_schedule
        @initial_schedule = []
        count.times do
          @initial_schedule.concat initial_schedule
        end
      else
        @initial_schedule = initial_schedule
      end

      @schedule = @initial_schedule.dup
      @prev_rotation = build_prev_rotation_hash(prev_rotation)
      @prev_rotation_save = prev_rotation
    end

    def inspect
      "<ScheduleMaker::Rotation schedule=#{@schedule.inspect}, pain=#{pain}, painscore=#{painscore} >"
    end

    def dup
      ScheduleMaker::Rotation.new(@participants, nil, @prev_rotation_save, @schedule.dup)
    end

    def iterate
      calculate_pain if @pain.nil? || @pain.empty?
      users_in_pain = @pain.keys.sort_by { |k| -@pain[k][:score] }
      trial = self.dup
      0.upto(1 + Random.rand(3)) do
        user_to_swap = ScheduleMaker::Util.randomelement(users_in_pain)
        user_index = @schedule.each_index.select{ |i| @schedule[i].participant == user_to_swap }
        index_1 = user_index.shuffle[0]
        begin_swap = [0, index_1 - Random.rand(@participants.keys.size)].max
        end_swap = [@schedule.size - 1, index_1 + Random.rand(@participants.keys.size)].min
        current_score = trial.painscore(true)
        begin_swap.upto(end_swap) do |index_2|
          next if index_1 == index_2
          next if trial.schedule[index_1].participant == trial.schedule[index_2].participant
          trial.swap(index_1, index_2)
          new_score = trial.painscore(true)
          if new_score >= current_score || rand > 0.90
            trial.swap(index_1, index_2)
          end
        end
      end
      trial.recalculate_pain
      trial
    end

    def swap(index_1, index_2)
      @schedule[index_1], @schedule[index_2] = @schedule[index_2], @schedule[index_1]
    end

    def pain
      calculate_pain if @pain.nil?
      @pain
    end

    def painscore(force_calc = false)
      calculate_pain if @pain.nil? || force_calc
      result = 0.0
      is_pain = false
      @pain.keys.each do |participant|
        is_pain = true if @pain[participant][:pain]
        result += @pain[participant][:score] ** 2
      end
      is_pain ? result.to_i : 0
    end

    def recalculate_pain
      calculate_pain
    end

    private

    def build_prev_rotation_hash(prev_rotation)
      result = {}
      counter = 0
      prev_rotation.each do |period|
        counter += 1
        next if result.key?(period.participant)
        result[period.participant] = counter
      end
      result
    end

    def build_initial_participant_arrays
      participants_by_period = {}
      period_lengths = @participants.values.uniq.sort
      period_lengths.each do |period_length|
        participants = @participants.keys.select { |x| @participants[x] == period_length }.sort
        participants_by_period[period_length] ||= []
        (@period_lcm/period_length).times do
          participants_by_period[period_length].concat participants
        end
      end
      participants_by_period
    end

    def build_initial_schedule
      participants_by_period = build_initial_participant_arrays
      period_lengths = @participants.values.uniq.sort
      shortest_period = period_lengths.shift
      result = []

      # Distribute the participants with the shortest shift evenly and repeatedly
      participants_by_period[shortest_period].each do |participant|
        result << ScheduleMaker::Period.new(participant, shortest_period)
      end

      # Insert participants in longer shifts into the existing result
      period_lengths.each do |period_length|
        spacing = result.size / (1 + participants_by_period[period_length].size)
        counter = 0
        participants_by_period[period_length].each do |participant|
          counter += 1
          period = ScheduleMaker::Period.new(participant, period_length)
          result.insert(counter + counter * spacing - 1, period)
        end
      end
      result
    end

    def calculate_pain
      counter = 0
      result = {}
      prev = {}
      @pain = {}
      @schedule.each do |period|
        @pain[period.participant] ||= {}
        @pain[period.participant][:spacing] ||= []
        @pain[period.participant][:score] ||= 0
        @pain[period.participant][:pain] ||= false
        @pain[period.participant][:period_length] ||= period.period_length

        score = nil
        if prev.key?(period.participant)
          score = (@target_spacing * period.period_length) - (counter - prev[period.participant])
        elsif @pain[period.participant][:spacing].empty? && @prev_rotation.key?(period.participant)
          score = (@target_spacing * period.period_length) - (counter + @prev_rotation[period.participant])
        end
        unless score.nil?
          @pain[period.participant][:spacing] << (1.0 * score) / period.period_length
          if (1.0 * score) / period.period_length >= 1.0
            @pain[period.participant][:pain] = true if (1.0 * score) / period.period_length > 1.0
            @pain[period.participant][:pain] = true if @target_spacing <= 2
          end
          @pain[period.participant][:score] += Math.exp(1.0 * score / period.period_length) if score > 0.0
        end
        counter += period.period_length
        prev[period.participant] = counter
      end
      @pain
    end
  end
end
