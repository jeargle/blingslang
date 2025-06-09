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


export AccountUpdate, Account, AccountGroup, Economy, BlingTrajectory
export value_at_time, current_value, initial_value, simulate
export plot_trajectories, read_system_file


# Hack to avoid disallowed mutual type references.
abstract type AbstractAccount end

"""
Model for changing the value of an Account on specified days.
"""
mutable struct AccountUpdate
    value_change::Float64
    recurrence::AbstractString  # once, daily, weekly, monthly
    day::Int64  # specific recurrence day; 0 if recurrence is once or daily
    next_date::Union{Date, Nothing}  # used during simulation; initialized if recurrence is once
    target_account::Union{AbstractAccount, Nothing}

    function AccountUpdate(value_change::Float64, recurrence::AbstractString, day_str::AbstractString; target_account=nothing)
        day = tryparse(Int64, day_str)
        next_date = nothing
        if day != nothing
            return AccountUpdate(value_change, recurrence, day; target_account=target_account)
        elseif recurrence == "once"
            day = 0
            next_date = Date(day_str)
        else
            day = getfield(Dates, Symbol(day_str))
        end
        new(value_change, recurrence, day, next_date, target_account)
    end

    function AccountUpdate(value_change::Float64, recurrence::AbstractString, day::Int64; target_account=nothing)
        new(value_change, recurrence, day, nothing, target_account)
    end

    function AccountUpdate(value_change::Float64, recurrence::AbstractString; target_account=nothing)
        if recurrence != "daily"
            throw(ArgumentError("Must provide \"day\" argument if recurrence is not \"daily\"."))
        end
        new(value_change, recurrence, 0, nothing, target_account)
    end

end

Base.show(io::IO, update::AccountUpdate) = show(io, string(update.value_change, ", ", update.recurrence, ", ", update.day))
Base.show(io::IO, m::MIME"text/plain", update::AccountUpdate) = show(io, m, string(update.value_change, ", ", update.recurrence, ", ", update.day))


"""
Account model.

Holds a value that changes over time depending on growth rate and the actions of
associated AccountUpdates.
"""
struct Account <: AbstractAccount
    name::AbstractString
    value::Float64
    growth_rate::Float64  # annual
    updates::Array{AccountUpdate, 1}
    share_price::Union{AbstractAccount, Nothing}
    num_shares::Float64    # only active with share_price
    strike_price::Float64  # only active with share_price

    Account(name::AbstractString, value::Float64) = new(name, value, 0.0, [], nothing, 0.0, 0.0)
    Account(name::AbstractString, value::Float64, growth_rate::Float64) = new(name, value, growth_rate, [], nothing, 0.0, 0.0)
    Account(name::AbstractString, value::Float64, updates::Array{AccountUpdate, 1}) = new(name, value, 0.0, updates, nothing, 0.0, 0.0)

    function Account(name::AbstractString,
                     value::Float64,
                     growth_rate::Float64,
                     updates::Array{AccountUpdate, 1})
        new(name, value, growth_rate, updates, nothing, 0.0, 0.0)
    end

    function Account(name::AbstractString,
                     share_price::AbstractAccount,
                     num_shares::Float64,
                     strike_price::Float64,
                     updates::Array{AccountUpdate, 1})
        value = (share_price.value - strike_price) * num_shares
        new(name, value, 0.0, updates, share_price, num_shares, strike_price)
    end

end

Base.show(io::IO, account::Account) = show(io, string(account.name, ": ", account.value))
Base.show(io::IO, m::MIME"text/plain", account::Account) = show(io, m, string(account.name, ": ", account.value))


"""
AccountGroup model.

Organizational structure for a set of Accounts.
"""
struct AccountGroup
    name::AbstractString
    accounts::Array{Account, 1}
    AccountGroup(name::AbstractString, accounts::Array{Account, 1}) = new(name, accounts)
end

Base.show(io::IO, ag::AccountGroup) = show(io, string(ag.name, ": ", sum([a.value for a in ag.accounts])))
Base.show(io::IO, m::MIME"text/plain", account::AccountGroup) = show(io, m, string(ag.name, ": ", sum([a.value for a in ag.accounts])))


"""
Economy model.
"""
struct Economy
    name::AbstractString
    accounts::Array{Account, 1}
    AccountGroup(name::AbstractString, accounts::Array{Account, 1}) = new(name, accounts)
end

Base.show(io::IO, ag::Economy) = show(io, string(ag.name, ": ", sum([a.value for a in ag.accounts])))
Base.show(io::IO, m::MIME"text/plain", account::Economy) = show(io, m, string(ag.name, ": ", sum([a.value for a in ag.accounts])))



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
- `account::Account`
- `time::Float64`: fraction of a year

# Returns
- `Float64`: value of an Account after time has passed
"""
function value_at_time(account::Account, time::Float64)
    return account.value * (1.0 + account.growth_rate)^time
end


"""
    current_value(account_group)

Get the value of an AccountGroup.

# Arguments
- `account_group::AccountGroup`

# Returns
- total value of all Accounts in AccountGroup
"""
function current_value(account_group::AccountGroup)
    return sum([a.value for a in account_group.accounts])
end


"""
    initial_value(traj)

Get the initial value of a BlingTrajectory.

# Arguments
- `traj::BlingTrajectory`

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
- `traj::BlingTrajectory`

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
- `update::AccountUpdate`
- `date::Date`: next timestamp
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
- `account_group::AccountGroup`
- `date::Date`: initial timestep
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
- `update::AccountUpdate`
- `date::Date`: next timestep to apply update
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
    get_next_value(date, account, previous_value, share_price)

Get the value of an Account at the next timestep.

# Arguments
- `date::Date`: next timestep
- `account::Account`
- `previous_value`: previous value of account
- `share_price=nothing`:

# Returns
- next value
"""
function get_next_value(date::Date, account::Account, previous_value, share_price=nothing)
    if account.growth_rate != 0.0
        time = 1.0/365.0
        next_value = previous_value * (1.0 + account.growth_rate)^time
    elseif account.share_price != nothing
        next_value = (share_price - account.strike_price) * account.num_shares
    else
        next_value = previous_value
    end

    next_transfers = DefaultDict{Account, Float64}(0.0)

    for update in account.updates
        if update.next_date == date
            next_value += update.value_change
            if update.target_account != nothing
                next_transfers[update.target_account] -= update.value_change
            end
            set_next_date(update, date)
        end
    end

    return next_value, next_transfers
end


"""
    simulate(traj)

Simulate a BlingTrajectory for a period of time.

# Arguments
- `traj::BlingTrajectory`: trajectory to simulate
"""
function simulate(traj::BlingTrajectory)
    init_next_date(traj.account_group, traj.start_date)
    # Skip first index which is for timestep.
    account_to_index = Dict(a => i+1 for (i, a) in enumerate(traj.account_group.accounts))

    # Order Accounts so that dependencies are processed correctly.
    accounts = Array{Account, 1}()
    stock_accounts = Array{Account, 1}()
    for a in traj.account_group.accounts
        if a.share_price == nothing
            push!(accounts, a)
        else
            push!(stock_accounts, a)
        end
    end
    accounts = vcat(accounts, stock_accounts)

    for timestep in range(traj.start_date+Day(1), traj.stop_date)
        next_values = Vector{Any}([timestep])
        previous_values = last(traj.trajectories)
        account_transfers = DefaultDict{Account, Float64}(0.0)
        total = 0.0

        for a in accounts
            previous_value = previous_values[Symbol(a.name)]
            if a.share_price != nothing
                share_price = next_values[account_to_index[a.share_price]]
            else
                share_price = nothing
            end
            next_value, next_transfers = get_next_value(timestep, a, previous_value, share_price)
            push!(next_values, next_value)
            for (target, transfer_val) in next_transfers
                account_transfers[target] += transfer_val
            end
            total += next_value
        end

        # Adjust values with Account transfers.
        for (target, transfer_val) in account_transfers
            next_values[account_to_index[target]] += transfer_val
            total += transfer_val
        end

        push!(next_values, total)
        push!(traj.trajectories, next_values)
    end
end


"""
    read_system_file(filename)

Create a simulation system from a YAML setup file.

# Arguments
- `filename`: name of YAML setup file

# Returns
- `Dict`: holds "accounts", "account_groups", "trajectories", and "plots"
"""
function read_system_file(filename)
    setup = YAML.load(open(filename))

    system = Dict()

    # Build Accounts.
    accounts = Dict()
    stock_accounts = Dict()
    transfer_updates = []

    if haskey(setup, "accounts")
        for account_info in setup["accounts"]
            name = string(account_info["name"])

            if haskey(account_info, "value")
                value = account_info["value"]
            else
                value = 0.0
            end

            account_updates = Array{AccountUpdate, 1}()
            if haskey(account_info, "updates")
                for update_info in account_info["updates"]
                    value_change = float(update_info["value_change"])
                    recurrence = string(update_info["recurrence"])
                    update_args = [value_change, recurrence]

                    if haskey(update_info, "day")
                        push!(update_args, update_info["day"])
                    end

                    if haskey(update_info, "transfer_to")
                        push!(transfer_updates, (update_args, update_info["transfer_to"], name))
                    else
                        # Create AccountUpdates with no transfers
                        update = AccountUpdate(update_args...)
                        push!(account_updates, update)
                    end
                end
            end

            if haskey(account_info, "growth_rate")
                # Account with set growth_rate.
                growth_rate = account_info["growth_rate"]
                accounts[name] = Account(name, value, growth_rate, account_updates)
            elseif haskey(account_info, "share_price")
                # Stock option Account.
                account_info["account_updates"] = account_updates
                stock_accounts[name] = account_info
            else
                accounts[name] = Account(name, value, account_updates)
            end
        end

        # Create stock option Accounts.
        # These Accounts need existing share_price Accounts in order to
        # initialize their starting values.
        for (name, stock_account) in stock_accounts
            share_price = accounts[stock_account["share_price"]]
            num_shares = float(stock_account["num_shares"])
            if haskey(stock_account, "strike_price")
                strike_price = float(stock_account["strike_price"])
            else
                strike_price = 0.0
            end
            account_updates = stock_account["account_updates"]
            accounts[name] = Account(name, share_price, num_shares, strike_price, account_updates)
        end

        # Loop through AccountUpdates with transfers.
        # These are dependent on existing Accounts so they can only be
        # added after Accounts are instantiated.
        for (update_args, target_name, source_name) in transfer_updates
            target_account = accounts[target_name]
            update = AccountUpdate(update_args...; target_account=target_account)
            account = accounts[source_name]
            push!(account.updates, update)
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

    plots = []

    # Assemble plotting info.
    for plot_info in get(setup, "plots", [])
        plot = Dict()
        # Must have a file name
        plot["file_name"] = string(plot_info["file_name"])
        # Must have a BlingTrajectory
        plot["trajectory"] = string(plot_info["trajectory"])
        plot["account_names"] = []
        for account_name in get(plot_info, "account_names", [])
            push!(plot["account_names"], account_name)
        end
        plot["account_sums"] = []
        for account_sum in get(plot_info, "account_sums", [])
            sum_spec = Dict()
            sum_spec["sum_name"] = account_sum["sum_name"]
            sum_spec["account_names"] = [name for name in account_sum["account_names"]]
            push!(plot["account_sums"], sum_spec)
        end
        push!(plots, plot)
    end

    system["plots"] = plots

    return system
end


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


end
