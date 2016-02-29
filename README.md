# schedule_maker

## Overview

This gem is used to create a schedule, suitable for an on-call rotation, with these properties:

- Exactly one participant is on-call at a time
- Within a given schedule, each participant covers the same number of days (or other time unit of your choice)
- Each participant can select the number of consecutive days to be on call

This gem is most useful to allow different shift lengths. It creates an initial guess and then attempts to optimize the schedule with an algorithm similar to [simulated annealing](https://en.wikipedia.org/wiki/Simulated_annealing), which is a probabilistic technique.

When you use this gem, expect the following:

- It might take a while to create your schedule, as it samples many possible lineups
- If you run this more than once, you are not guaranteed the same output
- You are not guaranteed the most optimized schedule
