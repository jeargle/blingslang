# John Eargle (mailto: jeargle at gmail.com)
# blingslang

"""
    plot_trajectories(traj; account_names, account_sums)

Create a plot of values over time for specific Accounts.

# Arguments
- `traj::BlingTrajectory`: trajectory to plot
- `account_names`: list of Account names to plot
- `account_sums`: list of lists of Account names to sum and plot

# Returns
- plot object
"""
function plot_trajectories(traj::BlingTrajectory; account_names=[], account_sums=[])
    # Collect data for specific Accounts.
    x = traj.trajectories.date
    ys = [traj.trajectories[!, Symbol(an)] for an in account_names]

    line_names = copy(account_names)

    # Collect data for summed sets of Accounts.
    for sum_spec in account_sums
        traj_sum = sum([traj.trajectories[!, Symbol(an)] for an in sum_spec["account_names"]])
        push!(ys, traj_sum)
        push!(line_names, sum_spec["sum_name"])
    end

    p = plot(x, ys, label=permutedims(line_names), title="Balance over time", xlabel="Date", ylabel="Balance")

    return p
end


"""
    plot_trajectories(traj)

Create a plot of values over time for all Accounts.

# Arguments
- `traj::BlingTrajectory`: trajectory to plot

# Returns
- plot object
"""
function plot_trajectories(traj::BlingTrajectory)
    account_names = [a.name for a in traj.account_group.accounts]
    p = plot_trajectories(traj, account_names=account_names)

    return p
end
