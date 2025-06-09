# John Eargle (mailto: jeargle at gmail.com)
# blingslang

module blingslang

using Dates

using DataFrames
using DataStructures
using Plots
using Printf
using Random
using YAML


# Account
include("account.jl")
export AccountUpdate, Account, AccountGroup, Economy
export value_at_time, current_value, init_next_date, set_next_date, get_next_value

# Simulation
include("simulation.jl")
export BlingTrajectory
export initial_value, simulate, read_system_file

# Plot
include("plot.jl")
export plot_trajectories

end
