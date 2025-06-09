# John Eargle (mailto: jeargle at gmail.com)
# blingslang

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
