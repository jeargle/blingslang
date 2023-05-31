#!/usr/local/bin/julia

# John Eargle (mailto: jeargle at gmail.com)
# blingsim

using blingslang

using Dates

using ArgParse
using Plots
using Printf


"""
    read_file_and_simulate(filename)

Simulate a system specified by a config file.

# Arguments
- filename: YAML config file
"""
function read_file_and_simulate(filename)
    system = read_system_file(filename)
    account_group = system[1]
    bling_traj = BlingTrajectory("net worth", account_group)

    simulate(bling_traj, Dates.today() + Year(20))

    p = plot_trajectories(bling_traj)
    savefig(p, "all_values.svg")
    println("all values plotted")

    p = plot_trajectories(bling_traj, ["total"])
    savefig(p, "total_value.svg")
    println("total value plotted")

    println()
end


"""
    main()

Entrypoint for blingslang simulation script.
"""
function main()
    aps = ArgParseSettings()
    @add_arg_table! aps begin
        "configfile"
            help = "YAML system configuration file"
            required = true
    end

    parsed_args = parse_args(ARGS, aps)

    read_file_and_simulate(parsed_args["configfile"])
end

main()
