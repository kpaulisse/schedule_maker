#!/usr/bin/env ruby
# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

require_relative '../lib/schedule_maker'
require 'fileutils'
require 'optparse'
require 'yaml'

# Colorize text
class String
  def red
    "\e[1m\e[31m" + self + "\e[0m"
  end

  def green
    "\e[1m\e[32m" + self + "\e[0m"
  end

  def white
    "\e[1m\e[37m" + self + "\e[0m"
  end
end

# Validate schedule
# @param schedule [ScheduleMaker::Schedule] A schedule object to validate
# @param ruleset [Hash] Rules to evaluate schedule
# @return [Boolean] true if schedule is valid; false if it's not
def valid?(schedule, ruleset, options)
  return false if schedule.nil?
  return true unless options[:validation]
  start_str = options[:start].strftime('%Y-%m-%dT%H:%M:%S')
  puts "- Validating schedule beginning #{start_str}...".white
  result = schedule.rotation.valid?(ruleset)
  return true if result
  puts '- Violation(s) detected'.red
  puts schedule.rotation.violations.map { |x| "   #{x.inspect}".red }.join("\n")
  false
end

# Main program flow
def main(options)
  raise "Error: Missing option '-c <rotation_file>'; please see #{File.basename(__FILE__)} --help" if options[:rotation_yaml].nil?
  rotation_yaml = ScheduleMaker::Util.load_rotation_from_yaml(options[:rotation_yaml], options[:valid_shift_lengths])
  schedule = nil
  until valid?(schedule, options[:ruleset], options)
    start_str = options[:start].strftime('%Y-%m-%dT%H:%M:%S')
    puts "- Building schedule beginning #{start_str}...".white
    schedule = ScheduleMaker::Schedule.new(rotation_yaml, options)
    schedule.optimize(
      max_iterations: schedule.rotation.rotation_length * schedule.rotation.participants.keys.size,
      reset_try_max: options[:optimize_passes],
      reset_max: schedule.rotation.participants.keys.size + 5
    )
  end

  if options[:output_file]
    puts "- Schedule being written to #{options[:output_file]}".green
    $stdout.reopen(options[:output_file], 'w')
  else
    puts '- Schedule generation succeeded! Here it is:'.green
  end
  puts schedule.render_erb('stats/summary_stats', :stats, '# ')
  puts schedule.render_erb('stats/individual_stats', :stats, '# ')
  puts schedule.to_yaml(with_stats: options[:details])
end

options = {
  debug: false,
  details: false,
  rotation: nil,
  start: ScheduleMaker::Util.midnight_today,
  rotation_count: 1,
  optimize_passes: 1,
  validation: true,
  output_file: nil,
  valid_shift_lengths: [1, 2, 4],
  ruleset: YAML.load_file(File.join(File.expand_path('../rulesets', File.dirname(__FILE__)), 'standard-spacing-algorithm.yaml'))
}

OptionParser.new do |opts|
  opts.banner = 'Usage: schedule.rb [options]'

  # This option is required so the program knows your rotation. The rotation must be a
  # YAML format in the following format (start and timezone are optional for each):
  #
  # participant_name:
  #   period_length: 2
  #   start: '2016-05-01T00:00:00'
  #   timezone: 'America/New_York'
  # participant2_name:
  #   period_length: 1
  #   start: '2016-05-15T00:00:00'
  #   timezone: 'America/Chicago'
  opts.on('-c', '--config=FILENAME', 'Specify rotation config YAML file') do |rotation_file|
    filepath = rotation_file =~ %r{/} ? rotation_file : File.join(Dir.getwd, rotation_file)
    raise "Specified rotation file '#{rotation_file}' does not exist" unless File.file?(filepath)
    options[:rotation_yaml] = filepath
  end

  # Specify the start date for rotation; default to midnight tonight
  opts.on('-s', '--start=YYYY-MM-DDTHH:MM:SS', 'Start date for rotation') do |start_date|
    options[:start] = ScheduleMaker::Util.dateparse(start_date)
  end

  # Specify the previous rotation, which must be a YAML file in the format that is output
  # by this gem. Example of the YAML format:
  #
  # - start: '2016-07-22T00:00:00+00:00'
  #   end: '2016-07-23T00:00:00+00:00'
  #   assignee: participant_name
  #   length: 1
  # - start: '2016-07-23T00:00:00+00:00'
  #   end: '2016-07-24T00:00:00+00:00'
  #   assignee: participant2_name
  #   length: 1
  opts.on('-p', '--previous=FILENAME', 'Specify previous rotation file') do |rotation_file|
    filepath = rotation_file =~ %r{/} ? rotation_file : File.join(archive_dir, rotation_file)
    raise "Specified previous rotation file '#{rotation_file}' does not exist" unless File.file?(filepath)
    options[:previous] = filepath
  end

  # Number of consecutive rotations to create; defaults to 1
  opts.on('--details', 'Include additional details in the scheduling') do |details|
    options[:details] = details
  end

  # Number of consecutive rotations to create; defaults to 1
  opts.on('-n', '--number=NUMBER', 'Number of rotations') do |count|
    options[:rotation_count] = count.to_i
  end

  # Number of optimization passes; defaults to 1. (Keep this at 1 and enable validation if
  # you just want an acceptable schedule. Turn this up to a higher number and disable validation
  # if you want a good schedule. Turn this up to a higher number and enable validation for the
  # best schedule.)
  opts.on('--optimization-passes=NUMBER', 'Number of passes during optimize') do |passes|
    options[:optimize_passes] = passes.to_i
  end

  # Output file: should we output the final schedule as a YAML file somewhere? If you want this,
  # specify the full path.
  opts.on('-o', '--output-file=FILENAME', 'Write out the result to a file somewhere') do |filename|
    if File.file?(filename)
      options[:output_file] = filename
    else
      begin
        FileUtils.touch(filename)
        File.unlink(filename)
        options[:output_file] = filename
      rescue Errno::ENOENT => exc
        raise "Invalid output file #{filename}: #{exc.message}"
      end
    end
  end

  # Valid shift lengths
  opts.on('--shift-lengths=X,Y,Z', Array, 'Set valid shift lengths (default 1,2,4)') do |valid_lengths|
    options[:valid_shift_lengths] = []
    valid_lengths.each do |len|
      raise "Error: Invalid shift length '#{len}' (must be numeric)" unless len =~ /^\d+$/
      options[:valid_shift_lengths] << len.to_i
    end
  end

  # Rule set configuration file
  opts.on('-r', '--ruleset=FILE1,FILE2,...', Array, 'Load rule set(s) from files') do |ruleset_files|
    options[:ruleset] = {}
    ruleset_files.each do |file|
      data = ScheduleMaker::Util.load_ruleset(file)
      puts "- Loaded ruleset: #{File.basename(file).gsub(/\.yaml$/, '')}".white
      data.each do |k, v|
        options[:ruleset][k] = v
      end
    end
  end

  # Validation mode
  opts.on('-v', '--[no-]validation', 'Turn validation on or off') do |validation|
    options[:validation] = validation
  end

  # Debugging mode
  opts.on('-d', '--debug', 'Turn on debugging output') do |debug|
    options[:debug] = debug
  end
end.parse!

main(options)
