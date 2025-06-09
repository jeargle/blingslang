# John Eargle (mailto: jeargle at gmail.com)
# blingslang

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
