blingslang
==========

Personal finance simulator


General
-------

The basic idea for this project is to simulate net worth over time for a collection of assets.

Individual assets are modeled through `Accounts`, which can then be pulled together into `AccountGroups`.  So for an individual with a retirement investment account, a mortgage, and income from labor, you could set up an `AccountGroup` containing 3 `Accounts`, set the initial values and growth characteristics of the `Accounts`, and then simulate the whole system using a day-length timestep within the context of an `Economy`.  `Accounts` and `Economies` can be completely deterministic, or they can incorporate stochastic elements.  The end result is value-over-time plots for the `Accounts` as well as the full `AccountGroup`.

Simulations are set up through simple, YAML-based config files.  This makes it easy to run many simulations while tweaking parameters to get a feel for possible growth trajectories for different kinds of `Accounts`.


Setup File
----------

The main three sections of the YAML system setup file are: `accounts`, `account_groups`, and `trajectories`.  Each `Account`, its starting value, and its growth parameters is defined in the `accounts` section.  `AccountGroups`, collections of `Accounts`, are defined in the `account_groups` section.  `BlingTrajectories` are value-over-time trajectories for `Accounts` and `AccountGroups`, and they are specified in the `trajectories` section.

Here is an example setup file:

    accounts:
      - name: A
        value: 10000.0
        updates:
          - value_change: 1200
            recurrence: weekly
            day: Friday
          - value_change: -2600
            recurrence: monthly
            day: 3
          - value_change: -200
            recurrence: weekly
            day: Friday
            transfer_to: C
      - name: B
        value: 50000.0
        growth_rate: 0.08
      - name: C
        value: 2000.0

    account_groups:
      - name: Group1
        accounts:
        - A
        - B
        - C

    trajectories:
      - name: net worth
        account_group: Group1
        stop_date: 2028-08-05

In this system, there are three `Accounts` (A, B, and C), one `AccountGroup` (Group1) consisting of all three `Accounts`, and one `BlingTrajectory` (net worth) that will track Group1 values from today until 2028-08-05.  `Account` A has a starting value of 10,000 and changes based on three regular `AccountUpdates`: one that adds 1200 every Friday, one that removes 2600 on the 3rd of each month, and one that transfers 200 every Friday to `Account` C.  This could represent a weekly paycheck of $1200, a monthly housing payment of $2600, and a weekly transfer of $200 to a savings account.  `Account` B starts at 50,000 and has a yearly growth rate of 0.08, or 8%, and could represent some investment.  The growth of B will actually be applied daily so there is no need to specify a recurrence time.  `Account` C starts with 2000, and only changes when funds are transferred from `Account` A.  Notice that transfers only need to be specified from one side.  The `transfer_to` entry within `Account` A's third update will automatically set up a corresponding addition of 200 to `Account` C.

The only `AccountGroup` in this file is Group1 consisting of all three `Accounts`.  When the simulation is run, it will record the daily values of the `Accounts` as well as the total value of Group1.  The net worth `BlingTrajectory` will be run based on Group1.  By default the starting date is the current day.  The `stop_date` is when the simulation will end, and it should be in YYYY-MM-DD format.  The `BlingTrajectory` stores all values in a DataFrame, and trajectories can be plotted to output SVG files.


Dependencies
------------

* ArgParse
* DataFrames
* DataStructures
* Plots
* Printf
* Random
* YAML
