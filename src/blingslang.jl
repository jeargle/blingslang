# John Eargle (mailto: jeargle at gmail.com)
# blingslang

module blingslang

using Dates

using DataFrames
using Plots
using Printf
using Random
using YAML


export AccountUpdate, Account, AccountGroup, BlingTrajectory
export value_at_time, current_value, initial_value, simulate
export plot_trajectories, read_system_file


"""
Model for changing the value of an Account on certain days.
"""
mutable struct AccountUpdate
    value_change::Float64
    recurrence::AbstractString  # once, daily, weekly, monthly
    day::Int64  # specific recurrence day; 0 if recurrence is once or daily
    next_date::Union{Date, Nothing}  # used during simulation; initialized if recurrence is once

    function AccountUpdate(value_change::Float64, recurrence::AbstractString, day_str::AbstractString)
        day = tryparse(Int64, day_str)
        next_date = nothing
        if day != nothing
            return AccountUpdate(value_change, recurrence, day)
        elseif recurrence == "once"
            day = 0
            next_date = Date(day_str)
        else
            day = getfield(Dates, Symbol(day_str))
        end
        new(value_change, recurrence, day, next_date)
    end

    function AccountUpdate(value_change::Float64, recurrence::AbstractString, day::Int64)
        new(value_change, recurrence, day, nothing)
    end

    function AccountUpdate(value_change::Float64, recurrence::AbstractString)
        if recurrence != "daily"
            throw(ArgumentError("Must provide \"day\" argument if recurrence is not \"daily\"."))
        end
        new(value_change, recurrence, 0, nothing)
    end

end

Base.show(io::IO, update::AccountUpdate) = show(io, string(update.value_change, ", ", update.recurrence, ", ", update.day))
Base.show(io::IO, m::MIME"text/plain", update::AccountUpdate) = show(io, m, string(update.value_change, ", ", update.recurrence, ", ", update.day))


"""
Account model.
"""
struct Account
    name::AbstractString
    value::Float64
    growth_rate::Float64  # annual
    updates::Array{AccountUpdate, 1}

    Account(name::AbstractString, value::Float64) = new(name, value, 0.0, [])
    Account(name::AbstractString, value::Float64, growth_rate::Float64) = new(name, value, growth_rate, [])
    Account(name::AbstractString, value::Float64, updates::Array{AccountUpdate, 1}) = new(name, value, 0.0, updates)
    Account(name::AbstractString, value::Float64, growth_rate::Float64, updates::Array{AccountUpdate, 1}) = new(name, value, growth_rate, updates)
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
    stop_date::Date
    trajectories::DataFrame
    # event_counters

    function BlingTrajectory(name::AbstractString, account_group::AccountGroup, stop_date::Date; start_date::Date=Dates.today())
        # Column for date.
        names = [:date]
        # start_date = Dates.today()
        values = Vector{Any}([start_date])

        for a in account_group.accounts
            push!(names, Symbol(a.name))
            push!(values, a.value)
        end

        # Column for AccountGroup totals.
        push!(names, :total)
        push!(values, current_value(account_group))

        trajectories = DataFrame(; zip(names, values)...)

        new(name, account_group, 0, start_date, stop_date, trajectories)
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
    init_next_date(update, date)

Set the initial value for next date that an AccountUpdate should be applied.

# Arguments
- update::AccountUpdate
- date::Date
"""
function init_next_date(update::AccountUpdate, date::Date)
    # "once" does not need to be handled
    if update.recurrence == "daily"
        update.next_date = date + Day(1)
    elseif update.recurrence == "weekly"
        weekday = update.day
        if dayofweek(date) <= weekday
            update.next_date = date + Day(weekday - dayofweek(date))
        else
            update.next_date = date + Day(7 + weekday - dayofweek(date))
        end
    elseif update.recurrence == "monthly"
        # handle 29-31 specially
        monthday = update.day
        if day(date) <= monthday
            update.next_date = date + Day(monthday - day(date))
        else
            update.next_date = date + Day(30 + monthday - day(date))
        end
    elseif update.recurrence == "yearly"

    end
end


"""
    init_next_date(account_group, date)

Set the initial value for next date of all AccountUpdates within an AccountGroup.

# Arguments
- account_group::AccountGroup
- date::Date
"""
function init_next_date(account_group::AccountGroup, date::Date)
    for account in account_group.accounts
        for update in account.updates
            init_next_date(update, date)
        end
    end
end


"""
    set_next_date(update, date)

Set the next date that an AccountUpdate should be applied.

# Arguments
- update::AccountUpdate
- date::Date
"""
function set_next_date(update::AccountUpdate, date::Date)
    # "once" does not need to be handled
    if update.recurrence == "daily"
        update.next_date = date + Day(1)
    elseif update.recurrence == "weekly"
        update.next_date = date + Week(1)
    elseif update.recurrence == "biweekly"
        update.next_date = date + Week(2)
    elseif update.recurrence == "monthly"
        # handle 29-31 specially
        update.next_date = date + Month(1)
    elseif update.recurrence == "yearly"
        update.next_date = date + Year(1)
    end
end


"""
    get_next_value(date, account, previous_value)

Get the value of an account at the next timestep.

# Arguments
- date::Date
- account::Account
- previous_value

# Returns
- next value
"""
function get_next_value(date::Date, account::Account, previous_value)
    if account.growth_rate != 0.0
        time = 1.0/365.0
        next_value = previous_value * (1.0 + account.growth_rate)^time
    else
        next_value = previous_value
    end

    for update in account.updates
        if update.next_date == date
            next_value += update.value_change
            set_next_date(update, date)
        end
    end

    return next_value
end


"""
    simulate(traj)

Simulate a BlingTrajectory for a period of time.

# Arguments
- traj::BlingTrajectory

# Returns
- BlingTrajectory
"""
function simulate(traj::BlingTrajectory)
    init_next_date(traj.account_group, traj.start_date)
    for timestep in range(traj.start_date+Day(1), traj.stop_date)
        next_values = Vector{Any}([timestep])
        previous_values = last(traj.trajectories)
        total = 0.0
        for a in traj.account_group.accounts
            previous_value = previous_values[Symbol(a.name)]
            next_value = get_next_value(timestep, a, previous_value)
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

    system = Dict()

    # Build Accounts.
    accounts = Dict()

    if haskey(setup, "accounts")
        for account_info in setup["accounts"]
            name = string(account_info["name"])
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

    # println(accounts)

    system["accounts"] = accounts

    # Build AccountGroups.
    account_groups = Dict()

    if haskey(setup, "account_groups")
        for account_group_info in setup["account_groups"]
            group_accounts = Array{Account, 1}()
            for account_name in account_group_info["accounts"]
                push!(group_accounts, accounts[string(account_name)])
            end
            name = string(account_group_info["name"])
            account_group = AccountGroup(name, group_accounts)
            # push!(account_groups, account_group)
            account_groups[name] = account_group
        end
    end

    system["account_groups"] = account_groups

    trajectories = Dict()

    # Build BlingTrajectory.
    if haskey(setup, "trajectories")
        for trajectory_info in setup["trajectories"]
            # Must have a name
            name = string(trajectory_info["name"])
            # Must have an AccountGroup
            account_group = account_groups[string(trajectory_info["account_group"])]
            if haskey(trajectory_info, "stop_date")
                stop_date = Date(string(trajectory_info["stop_date"]))
            else
                stop_date = Dates.today() + Year(20)
            end
            trajectory = BlingTrajectory(name, account_group, stop_date)
            trajectories[name] = trajectory
        end
    end

    system["trajectories"] = trajectories

    return system
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

    p = plot(x, ys, label=permutedims(account_names), title="Balance over time", xlabel="Date", ylabel="Balance")

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
