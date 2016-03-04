# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker::DataModel
  # This class determines "fairness" of a particular schedule by calculating the
  # percentage of the time a person is assigned to a weekend. The result for each
  # participant is a number from 0 (no weekend at all) to 1 (all weekend).
  #
  # Options:
  # - minimum_shift_hours [Fixnum] Don't report on participants covering less than this number of hours
  class Weekdays
    # Constructor
    # @param options [Hash] Global options
    def initialize(options = {})
      @global_options = options
      @pain_override = nil
    end

    # Calculate the pain array
    # @param rotation [ScheduleMaker::Rotation] Rotation object
    # @param options [Hash] Options to override global options
    # @result [Hash<Participant,Fixnum>] Pain score for each participant
    def pain(rotation, options_in = {})
      return @pain_override unless @pain_override.nil?
      options = @global_options.merge(options_in)
      # FIXME
      {}
    end

    # Override pain array - FOR USE IN SPEC TESTING ONLY
    def override_pain_from_a_spec_test_only(pain)
      @pain_override = pain
    end
  end
end
