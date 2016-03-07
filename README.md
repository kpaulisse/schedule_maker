# schedule_maker

[![Build Status](https://travis-ci.org/kpaulisse/schedule_maker.svg?branch=master)](https://travis-ci.org/kpaulisse/schedule_maker)

This gem helps you create a schedule with varying shift lengths. Each participant is assigned to the same total number of days within the schedule, and an individual's shifts are spaced out as much as possible. This gem is particularly useful to allow participants to select different shift lengths.

Requires Ruby >= 2.1

## Overview

The resulting schedule will always have these properties:

- The schedule is a series of consecutive, non-overlapping shifts
- Each shift has exactly one assignee
- Each participant covers the same total number of days (or other time unit of your choice)
- Supports adding participants only after a certain date
- Supports treat week/weekend days different from other days

This gem does **not** currently do any of the following, although I may work on some or all of these in the future:

- Support holidays
- Support non-equal distribution of days per participant
- Support blackout dates per participant (e.g., avoid vacation days)

If you use this gem, expect the following:

- The schedule optimization is performed with a probabilistic technique (i.e., random samples) and this may take a while
- If you generate a schedule more than once, you will probably get different output
- You are not guaranteed to receive the *most* optimized schedule or a *perfectly* optimized schedule

## How to install

It's easiest to install this with `bundler` by placing this in a `Gemfile`:

```
gem 'schedule_maker', git: 'https://github.com/kpaulisse/schedule_maker.git'
```

Now, in the directory where you have the `Gemfile`, pull in the gem:

```
bundle install
```

## How to use

This gem comes with a script intended to be run from the command line to let you use this functionality without doing any programming of your own. In order to do this you'll have to do the following:

- Construct your rotation configuration (YAML file)
- Construct your rule set(s) (Optional)

Once you've done that, you can run the command with the appropriate arguments.

### Construct your rotation configuration (YAML file)

The rotation configuration file is a YAML file that describes a hash. The keys are the names of the people in your rotation. The values accept parameters that configure their preferences.

Here is an example file for you to model:

```
Adam:
  period_length: 1
  timezone: 'America/Chicago'
Bob:
  period_length: 2
  start: '2016-06-01T00:00:00'
  timezone: 'America/New York'
Charles:
  period_length: 4
  timezone: 'America/Los_Angeles'
```

The `period_length` is required, and this must correspond to the desired shift length (in days). In the example above, Adam will have 1 day shifts, Bob will have 2 day shifts, and Charles will have 4 day shifts.

The `start` is optional, and is used only when a particular person should not be added to the schedule until a particular date. In the example above, Adam and Charles will be placed in the rotation immediately, but Bob will only be placed in the rotation for shifts that start on or after June 1, 2016.

The `timezone` is optional, but recommended. This will be used to calculate day-based statistics (i.e., what percentage of the shifts occur on weekends). For a geographically distributed rotation, this personalizes the shifts. UTC is the default, for anyone for whom the time zone is not specified.

### Construct your rule set(s)

Documentation not yet written.

Please see [rulesets](./rulesets) for examples.

### Run command with arguments

Run `schedule.rb --help` for a current list of options.

Common options:

- `-c <Rotation Config Filename>`: YAML file containing your rotation definition. The format is described above. (**REQUIRED**)

- `-s YYYY-MM-DDT00:00:00`: Start date for your rotation. (Optional; default = midnight on day script is run)

- `-n <Number of rotations>`: Number of consecutive rotations to create. (Optional; default = 1)

- `-o <Output file>`: Dump schedule as YAML to this file. Note that this file will be overwritten if it exists. (Optional; default = dump output to the console)

# Developer Guide

In your code write this:

```
require 'bundler/setup'
require 'schedule_maker'
```

You can now use the gem.

# Additional Information

## Debug mode

When running the provided script with the `-d` option, or when programming your own and instantiating the `ScheduleMaker::Schedule`, passing the option `:debug => true` will enable debugging mode. Because optimizing the rotation may take a while, if you want to see a lot of stuff printed on your screen, debug mode may be handy for you.

When you enable debugging you'll see lines like this, over and over again:

```
- Loaded ruleset: weekends-are-bad.yaml
- Loaded ruleset: standard-spacing-algorithm.yaml
- Building schedule beginning 2016-04-13T00:00:00...
  Better schedule found: previous=506384012 better=134823
Time: 1<1470|0<19|0<1; Pain=506384012|134823|506384012|134823
  Better schedule found: previous=134823 better=19524
Time: 2<1470|0<19|0<1; Pain=134823|19524|506384012|19524
  Better schedule found: previous=19524 better=9229
Time: 3<1470|0<19|0<1; Pain=19524|9229|506384012|9229
  Better schedule found: previous=9229 better=6043
Time: 4<1470|0<19|0<1; Pain=9229|6043|506384012|6043
  Better schedule found: previous=6043 better=5110
Time: 5<1470|0<19|0<1; Pain=6043|5110|506384012|5110
  Better schedule found: previous=5110 better=5045
Time: 6<1470|0<19|0<1; Pain=5110|5045|506384012|5045
  Better schedule found: previous=5045 better=4475
Time: 7<1470|0<19|0<1; Pain=5045|4475|506384012|4475
  Better schedule found: previous=4475 better=4079
Time: 8<1470|0<19|0<1; Pain=4475|4079|506384012|4079
Time: 9<1470|1<19|0<1; Pain=4079|5920|506384012|4079
Time: 10<1470|2<19|0<1; Pain=4079|4823|506384012|4079
Time: 11<1470|3<19|0<1; Pain=4079|4917|506384012|4079
  Better schedule found: previous=4079 better=3012
Time: 12<1470|0<19|0<1; Pain=4079|3012|506384012|3012
Time: 13<1470|1<19|0<1; Pain=3012|3094|506384012|3012
Time: 14<1470|2<19|0<1; Pain=3012|3661|506384012|3012
```

Examining this output:

```
Time: 7<1470|0<19|0<1; Pain=5045|4475|506384012|4475
  Better schedule found: previous=4475 better=4079
Time: 8<1470|0<19|0<1; Pain=4475|4079|506384012|4079
Time: 9<1470|1<19|0<1; Pain=4079|5920|506384012|4079
```

From left to right, here is what these numbers all mean:

- `7<1470`: This is the 7th iteration, out of a maximum of 1470 iterations. If somehow (very unlikely) it reaches 1470 total iterations without finding a pain-free rotation or exhausting the master reset counter, the optimization will end.
- `0<19`: This is the 1st try (out of a maximum of 19) to try to obtain a lower pain score from this particular starting point. The try counter resets back to 0 whenever a lower pain score was achieved. Between the 7th and 8th iteration, you can see that a better score was achieved, so the try counter is still at 0. However, between the 8th and 9th iteration, there was no improvement, so this counter advanced to 1.
- `0<1`: This is the master reset status, and this optimization has started over 0 times out of a maximum of 1. When this counter reaches 1 without having improved upon the best score, the optimization ends. Note that this counter resets back to 1 *any* time that a new "best" pain score is found. The maximum counter, in this case 1, can be changed from the command line by specifying `--optimization-passes=NUMBER`.
- `Pain=5045|4475|506384012|4475`: These numbers represent the pain scores for the current iteration before swaps, current iteration after swaps, initial pain score, and best-ever pain score. In this particular example, this iteration found a new best-ever pain score.

As you are watching this scroll by, the most interesting numbers to pay attention to are the third column (in the example above, `0<1`) and the best pain score in the last column (`4475`). The master reset counter will give you a good idea of how much time is left until the optimization ends. The best pain score gives you an idea of how optimized the rotation is -- low numbers are good here, and you should see this decrease pretty rapidly at first, and then level off as the master reset counter starts to grow. It's also possible that the last number will drop to 0, which means you've found a pain-free rotation and you're done! :tada:

## Tips

- Keep in mind that random numbers play a big part in your success, meaning that your success is random. Sometimes the algorithm will find an optimal solution really quickly, and sometimes it will spin for several minutes and then return a result that's not so great.
- Consider running this a few times (as in, restarting your program from scratch, or at least instantiating a brand new call to this gem a few times). Keep track of the "best score" and resulting rotation from a few trials.
- If you are using this for something potentially painful, such as an on-call schedule, don't underestimate the human factors that go into it. Put :eyes: on the result and manually check for badness before automatically publishing the result. (In particular, make sure that your optimal score wasn't achieved by disadvantaging one or two people substantially more than the rest of the group.)
