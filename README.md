# schedule_maker

This gem helps you create a schedule with varying shift lengths. Each participant is assigned to the same total number of days within the schedule, and an individual's shifts are spaced out as much as possible. This gem is particularly useful to allow participants to select different shift lengths.

## Overview

The resulting schedule will always have these properties:

- The schedule is a series of consecutive, non-overlapping shifts
- Each shift has exactly one assignee
- Each participant covers the same total number of days (or other time unit of your choice)
- Supports adding participants only after a certain date

This gem does **not** currently do any of the following, although I may work on some or all of these in the future:

- Distribute shifts on certain days (e.g., treat weekend days or holidays different from any other days)
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

In your code write this:

```
require 'bundler/setup'
require 'schedule_maker'
```

You can now use the gem. Better examples and documentation forthcoming.

## Debug mode

When instantiating the `ScheduleMaker::Schedule`, passing the option `:debug => true` will enable debugging mode. Because optimizing the rotation may take a while, if you want to see a lot of stuff printed on your screen, debug mode may be handy for you. If you're running this over a slow SSH connection, then it's probably not such a great idea.

When you enable debugging you'll see lines like this, over and over again:

```
Time: 2050<10816000|1<500|1<50; Pain=1370219|1301940|1370219|1814
Time: 2051<10816000|1<500|1<50; Pain=1301940|38703|1370219|1814
Time: 2052<10816000|1<500|1<50; Pain=38703|13774|1370219|1814
Time: 2053<10816000|1<500|1<50; Pain=13774|10876|1370219|1814
Time: 2054<10816000|1<500|1<50; Pain=10876|10876|1370219|1814
Time: 2055<10816000|2<500|1<50; Pain=10876|10876|1370219|1814
Time: 2056<10816000|3<500|1<50; Pain=10876|10876|1370219|1814
Time: 2057<10816000|4<500|1<50; Pain=10876|10876|1370219|1814
Time: 2058<10816000|5<500|1<50; Pain=10876|8643|1370219|1814
Time: 2059<10816000|1<500|1<50; Pain=8643|8643|1370219|1814
Time: 2060<10816000|2<500|1<50; Pain=8643|8643|1370219|1814
Time: 2061<10816000|3<500|1<50; Pain=8643|8643|1370219|1814
Time: 2062<10816000|4<500|1<50; Pain=8643|8643|1370219|1814
Time: 2063<10816000|5<500|1<50; Pain=8643|8643|1370219|1814
Time: 2064<10816000|6<500|1<50; Pain=8643|5891|1370219|1814
Time: 2065<10816000|1<500|1<50; Pain=5891|4775|1370219|1814
```

From left to right, here is what these numbers all mean:

- `2050<10816000`: This is the 2050th iteration, out of a maximum of 10816000 iterations. If somehow (very unlikely) it reaches 10816000 without finding a pain-free rotation or exhausting the master reset counter, the optimization will end.
- `1<500`: This is the 1st try (out of a maximum of 500) to try to obtain a lower pain score. The try counter resets back to 1 whenever a lower pain score was achieved. From the first to the second line, you can see that the pain score decreased from 1370219 to 1301940, so the second line also reads `1<500`. Later on, you see `2<500`, `3<500`, and so on. The pain score did not change, hence the counter increased. When this reaches the maximum of 500, this will trigger a master reset (see next column), resetting the rotation back to the initial state to try to find a better result down a different path.
- `1<50`: This is the master reset status, and this optimization is in the 1st overall reset out of 50 total. When this counter reaches 50 without having improved upon the best score, the optimization ends. (Note that this counter resets back to 1 *any* time that a new "best" pain score is found, i.e., we must fail 50 consecutive times before giving up.)
- `Pain=1370219|1301940|1370219|1814`: These numbers represent the pain scores for the current iteration before swaps, current iteration after swaps, initial pain score, and best-ever pain score.

As you are watching this scroll by, the most interesting numbers to pay attention to are the third column (in the example above, `1<50`) and the best pain score in the last column (`1814`). The master reset counter will give you a good idea of how much time is left until the optimization ends -- you will eventually see this climb all the way to `49<50` before it ends. The best pain score gives you an idea of how optimized the rotation is -- low numbers are good here, and you should see this decrease pretty rapidly at first, and then level off as the master reset counter starts to grow. It's also possible that the last number will drop to 0, which means you've found a pain-free rotation and you're done! :tada:

## Tips

- Keep in mind that random numbers play a big part in your success, meaning that your success is random. Sometimes the algorithm will find an optimal solution really quickly, and sometimes it will spin for several minutes and then return a result that's not so great.
- Consider running this a few times (as in, restarting your program from scratch, or at least instantiating a brand new call to this gem a few times). Keep track of the "best score" and resulting rotation from a few trials.
- If you are using this for something potentially painful, such as an on-call schedule, don't underestimate the human factors that go into it. Put :eyes: on the result and manually check for badness before automatically publishing the result. (In particular, make sure that your optimal score wasn't achieved by disadvantaging one or two people substantially more than the rest of the group.)
