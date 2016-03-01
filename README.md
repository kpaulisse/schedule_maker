# schedule_maker

This gem helps you create a schedule with varying shift lengths. Each participant is assigned to the same total number of days within the schedule, and an individual's shifts are spaced out as much as possible. This gem is particularly useful to allow participants to select different shift lengths.

## Overview

The resulting schedule will always have these properties:

- The schedule is a series of consecutive, non-overlapping shifts
- Each shift has exactly one assignee
- Each participant covers the same total number of days (or other time unit of your choice)

This gem does **not** currently do any of the following, although I may work on some or all of these in the future:

- Distribute shifts on certain days (e.g., treat weekend days or holidays different from any other days)
- Support non-equal distribution of days per participant
- Support blackout dates per participant (e.g., avoid vacation days, or add to schedule part way through)

If you use this gem, expect the following:

- The schedule optimization is performed with a probabilistic technique (i.e., random samples) and this may take a while
- If you generate a schedule more than once, you will probably get different output
- You are not guaranteed to receive the *most* optimized schedule or a *perfectly* optimized schedule
