# John Eargle (mailto: jeargle at gmail.com)
# 2023
# blingslang

module blingslang

using Plots
using Printf
using Random


export Account, AccountGroup

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


end
