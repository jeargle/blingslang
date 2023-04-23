blingslang
==========

simple money calculation tools


General
-------

The basic idea for this project is to simulate net worth over time for a collection of assets.

Individual assets are modeled through `Accounts`, which can then be pulled together into `AccountGroups`.  So for an individual with a retirement investment account, a mortgage, and income from labor, you could set up an `AccountGroup` containing 3 `Accounts`, set the initial values and growth characteristics of the `Accounts`, and then simulate the whole system using a day-length timestep within the context of an `Economy`.  `Accounts` and `Economies` can be completely deterministic, or they can incorporate stochastic elements.  The end result is value-over-time plots for the `Accounts` as well as the full `AccountGroup`.

Simulations are set up through simple, YAML-based config files.  This makes it easy to run many simulations while tweaking parameters to get a feel for possible growth trajectories for different kinds of `Accounts`.


Dependencies
------------

* Plots
* Printf
* Random
* YAML
