#!/usr/local/bin/julia --project=..

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

    for (traj_name, traj) in system["trajectories"]
        simulate(traj)

        for plot in system["plots"]
            file_name = plot["file_name"]
            traj = system["trajectories"][plot["trajectory"]]
            account_names = plot["account_names"]
            if length(account_names) > 0
                p = plot_trajectories(traj, account_names)
            else
                p = plot_trajectories(traj)
            end
            savefig(p, file_name)
            println("$(file_name) plotted")
        end
    end

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
