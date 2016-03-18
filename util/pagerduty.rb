#!/usr/bin/env ruby
#
# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker
#
# ------
# This script will import a schedule YAML file into a PagerDuty schedule as overrides.
#
# This script is NOT intended to be the be-all, end-all import script. It makes some
# assumptions, like with the user ID matching the portion of the e-mail address before
# the '@' sign. Hopefully this is flexible enough to let you customize it for your needs,
# if you need to.

require 'httparty'
require 'json'
require 'optparse'
require 'uri'
require 'yaml'

#
# Options parsing
#

options = {
  subdomain: nil,
  token: ENV['PAGERDUTY_TOKEN'],
  schedule: nil,
  file: nil,
  timezone: 'UTC'
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} -d <subdomain> -t <auth_token> -s <schedule_id> -f <filename> [-z <timezone>]"
  opts.on('--subdomain SUBDOMAIN', '-d', String, 'PagerDuty subdomain') { |x| options[:subdomain] = x }
  opts.on('--token TOKEN', '-t', String, 'PagerDuty auth token') { |x| options[:token] = x }
  opts.on('--schedule SCHEDULE_ID', '-s', String, 'PagerDuty schedule ID') { |x| options[:schedule] = x }
  opts.on('--file FILENAME', '-f', String, 'YAML file to import') { |x| options[:file] = x }
  opts.on('--timezone ZONE', '-z', String, 'Time zone (default UTC)') { |x| options[:timezone] = x }
end.parse!

#
# Options validation
#

raise 'Subdomain not specified' if options[:subdomain].nil?
raise 'Auth Token not specified' if options[:token].nil?
raise 'Schedule ID not specified' if options[:schedule].nil?
raise 'File name to import not specified' if options[:file].nil?
raise 'Import file is invalid' unless File.file?(options[:file])

#
# HTTParty caller, see example @ https://github.com/jnunemaker/httparty
#
class PagerDuty
  include HTTParty

  def initialize(subdomain, token)
    @subdomain = subdomain
    @options = {
      headers: {
        'Authorization' => "Token token=#{token}",
        'Content-type' => 'application/json'
      }
    }
  end

  def get(uri)
    full_uri = "https://#{@subdomain}.pagerduty.com#{uri}"
    self.class.get(full_uri, @options)
  end

  def post(uri, data)
    full_uri = "https://#{@subdomain}.pagerduty.com#{uri}"
    options = @options.merge(body: data)
    self.class.post(full_uri, options)
  end
end

#
# Convert assignee in on-call rotation to PagerDuty ID. This makes the assumption that
# the username in the schedule is the first part of the user's e-mail address. This may
# or may not be true in your case! Also, you may hit pagination limits if you have more
# than 100 users, so you'll have to account for that as well (this script doesn't).
#

pd = PagerDuty.new(options[:subdomain], options[:token])
assignees = {}
offset = 0
limit = 100
# Pagination, will break when we get back less than limit
while true
  user_list_url = "/api/v1/users?offset=#{offset}&limit=#{limit}"
  user_list_result = pd.get(user_list_url)
  raise "User list query returned HTTP #{user_list_result.response.code}" unless user_list_result.response.code == '200'
  users = user_list_result.parsed_response['users']
  users.each do |user_obj|
    next unless user_obj.key?('email') && user_obj['email'] =~ /^(.+?)@/
    assignees[Regexp.last_match(1)] = user_obj['id']
  end
  if users.size < limit
    # We've hit the end of the user list
    break
  end
  # Next page
  offset += limit
end

#
# Load the schedule and prepare the list of actions that need to be taken in PagerDuty
#

schedule = YAML.load_file(options[:file])
actions = []
schedule.each do |user_shift|
  raise "Unable to find PagerDuty ID for '#{user_shift[:assignee]}'!" unless assignees.key?(user_shift[:assignee])
  actions << { 'user_id' => assignees[user_shift[:assignee]], 'start' => user_shift[:start], 'end' => user_shift[:end] }
end

#
# Actually schedule overrides in PagerDuty
#

override_url = "https://#{options[:subdomain]}.pagerduty.com/api/v1/schedules/#{options[:schedule]}/overrides"
actions.each do |action|
  puts "Scheduling #{action['user_id']} for #{action['start']} - #{action['end']}..."
  body = JSON.generate('override' => action)
  result = pd.post(override_url, body)
  raise "Failed to create override, status code = #{result.response.code}" unless result.response.code == 201
  pr = result.parsed_response
  raise "Override failed: #{pr}" unless pr['override']['start'] == action['start'] &&
                                        pr['override']['end'] == action['end'] &&
                                        pr['override']['user']['id'] == action['user_id']
end

puts 'All done'
exit 0
