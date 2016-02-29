# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  class Period
    attr_reader :participant, :period_length

    def initialize(participant, period_length)
      @participant = participant
      @period_length = period_length
    end

    def to_s
      result = ""
      1.upto(@period_length) do |counter|
        result += "<#{@participant}: #{counter}/#{@period_length}>"
      end
      result
    end

    def inspect
      "<ScheduleMaker::Period '#{@participant}'=>'#{@period_length}'>"
    end
  end
end
