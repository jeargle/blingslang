# John Eargle (mailto: jeargle at gmail.com)
# 2023
# blingslang

module blingslang

using Dates

using DataFrames
using Plots
using Printf
using Random
using YAML


export Account, AccountGroup, BlingTrajectory
export value_at_time, current_value, initial_value, simulate
export plot_trajectories, read_system_file


"""
Account model.
"""
struct Account
    name::AbstractString
    value::Float64
    growth_rate::Float64  # annual

    Account(name::AbstractString, value::Float64) = new(name, value, 0.0)
    Account(name::AbstractString, value::Float64, growth_rate::Float64) = new(name, value, growth_rate)
end

Base.show(io::IO, account::Account) = show(io, string(account.name, ": ", account.value))
Base.show(io::IO, m::MIME"text/plain", account::Account) = show(io, m, string(account.name, ": ", account.value))


"""
AccountGroup model.
"""
struct AccountGroup
    name::AbstractString
    accounts::Array{Account, 1}
    AccountGroup(name::AbstractString, accounts::Array{Account, 1}) = new(name, accounts)
end

Base.show(io::IO, ag::AccountGroup) = show(io, string(ag.name, ": ", sum([a.value for a in ag.accounts])))
Base.show(io::IO, m::MIME"text/plain", account::AccountGroup) = show(io, m, string(ag.name, ": ", sum([a.value for a in ag.accounts])))


"""
Value over time for all Accounts in an AccountGroup.
"""
struct BlingTrajectory
    name::AbstractString
    account_group::AccountGroup
    step_count::Int
    start_date::Date
    trajectories::DataFrame
    # event_counters

    function BlingTrajectory(name::AbstractString, account_group::AccountGroup)
        # Column for date.
        names = [:date]
        start_date = Dates.today()
        values = Vector{Any}([start_date])

        for a in account_group.accounts
            push!(names, Symbol(a.name))
            push!(values, a.value)
        end

        # Column for AccountGroup totals.
        push!(names, :total)
        push!(values, current_value(account_group))

        trajectories = DataFrame(; zip(names, values)...)

        new(name, account_group, 0, start_date, trajectories)
    end
end

Base.show(io::IO, bt::BlingTrajectory) = show(io, bt.name)
Base.show(io::IO, m::MIME"text/plain", bt::BlingTrajectory) = show(io, m, bt.name)


"""
    value_at_time(account, time)

Get the future value for an Account.

# Arguments
- account::Account
- time::Float64: fraction of a year

# Returns
- value of an Account after time has passed
"""
function value_at_time(account::Account, time::Float64)
    return account.value * (1.0 + account.growth_rate)^time
end


"""
    current_value(account_group)

Get the value of an AccountGroup.

# Arguments
- account_group::AccountGroup

# Returns
- total value of all Accounts in AccountGroup
"""
function current_value(account_group::AccountGroup)
    return sum([a.value for a in account_group.accounts])
end


"""
    initial_value(traj)

Get the initial value of an BlingTrajectory.

# Arguments
- traj::BlingTrajectory

# Returns
- total initial value of all Accounts in a BlingTrajectory
"""
function initial_value(traj::BlingTrajectory)
    return current_value(traj.account_group)
end


"""
    current_value(traj)

Get the last value of an BlingTrajectory.

# Arguments
- traj::BlingTrajectory

# Returns
- total current value of all Accounts in a BlingTrajectory
"""
function current_value(traj::BlingTrajectory)
    current_row = last(traj.trajectories)
    values = [current_row[Symbol(a.name)]
              for a in traj.account_group.accounts]
    return sum(values)
end


"""
    get_next_value(account, previous_value)

Get the value of an account at the next timestep.

# Arguments
- account::Account
- previous_value

# Returns
- next value
"""
function get_next_value(account::Account, previous_value)
    time = 1.0/365.0
    return previous_value * (1.0 + account.growth_rate)^time
end


"""
    simulate(traj, stop_date)

Simulate a BlingTrajectory for a period of time.

# Arguments
- traj::BlingTrajectory
- stop_date::Date

# Returns
- BlingTrajectory
"""
function simulate(traj::BlingTrajectory, stop_date::Date)
    for timestep in range(traj.start_date+Day(1), stop_date)
        next_values = Vector{Any}([timestep])
        previous_values = last(traj.trajectories)
        total = 0.0
        for a in traj.account_group.accounts
            previous_value = previous_values[Symbol(a.name)]
            next_value = get_next_value(a, previous_value)
            push!(next_values, next_value)
            total += next_value
        end
        push!(next_values, total)
        push!(traj.trajectories, next_values)
    end
end


"""
    read_system_file(filename)

Create a simulation system from a YAML setup file.

# Arguments
- filename: name of YAML setup file

# Returns
- SYSTEMSIMULATION
"""
function read_system_file(filename)
    setup = YAML.load(open(filename))

    # build Accounts
    accounts = Dict()

    if haskey(setup, "accounts")
        for account_info in setup["accounts"]
            name = string(account_info["name"][1])
            value = account_info["value"]
            if haskey(account_info, "growth_rate")
                growth_rate = account_info["growth_rate"]
                account = Account(name, value, growth_rate)
            else
                account = Account(name, value)
            end
            accounts[name] = account
        end
    end

    # build AccountGroups
    account_groups = Array{AccountGroup, 1}()

    if haskey(setup, "account_groups")
        for account_group_info in setup["account_groups"]
            group_accounts = Array{Account, 1}()
            for account_name in account_group_info["accounts"]
                push!(group_accounts, accounts[string(account_name)])
            end
            name = string(account_group_info["name"])
            account_group = AccountGroup(name, group_accounts)
            push!(account_groups, account_group)
        end
    end

    return account_groups
end


"""
    plot_trajectories(traj, account_names)

Create a plot of Account values over time.

# Arguments
- traj::BlingTrajectory
- account_names

# Returns
- plot object
"""
function plot_trajectories(traj::BlingTrajectory, account_names)
    x = traj.trajectories.date
    ys = [traj.trajectories[!, Symbol(an)] for an in account_names]
    p = plot(x, ys)

    return p
end


"""
    plot_trajectories(traj)

Create a plot of Account values over time.

# Arguments
- traj::BlingTrajectory

# Returns
- plot object
"""
function plot_trajectories(traj::BlingTrajectory)
    account_names = [a.name for a in traj.account_group.accounts]
    p = plot_trajectories(traj, account_names)

    return p
end


"""
    plot_trajectory(traj)

Create a plot of AccountGroup value over time.

# Arguments
- traj::BlingTrajectory

# Returns
- plot object
"""
function plot_trajectory(traj::BlingTrajectory)
    x = traj.trajectories.date
    ys = [traj.trajectories[!, Symbol(an)] for an in account_names]
    p = plot(x, ys)

    return p
end


end
