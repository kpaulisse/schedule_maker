# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # This represents an on-call shift, but since "shift" is a reserved word in
  # nearly every programming language, I used "Period" instead.
  class Period
    attr_reader :participant, :period_length

    # Constructor
    #
    # @param participant [String] Name of participant/person associated with this shift
    # @param period_length [Fixnum] Length of the shift
    def initialize(participant, period_length)
      @participant = participant
      @period_length = period_length
    end

    # String representation
    # @return [String] String representation of the shift
    def to_s
      result = ''
      1.upto(@period_length) do |counter|
        result += "<#{@participant}: #{counter}/#{@period_length}>"
      end
      result
    end

    # Inspect representation
    # @return [String] Inspect representation of the shift
    def inspect
      "<ScheduleMaker::Period '#{@participant}'=>'#{@period_length}'>"
    end

    # Equality method
    # @param other [Period] The other period object to compare
    # @return [Boolean] true if it's a match, false otherwise
    def ==(other)
      return false unless other.is_a?(ScheduleMaker::Period)
      @participant == other.participant && @period_length == other.period_length
    end
  end
end
