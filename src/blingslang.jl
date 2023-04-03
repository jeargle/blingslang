# John Eargle (mailto: jeargle at gmail.com)
# 2023
# blingslang

module blingslang

using Plots
using Printf
using Random


export Account

"""
Account model.
"""
struct Account
    name::AbstractString
    value::Float64
    Account(name::AbstractString, value::Float64) = new(name, value)
end

Base.show(io::IO, account::Account) = show(io, string(account.name, ": ", account.value))
Base.show(io::IO, m::MIME"text/plain", account::Account) = show(io, m, string(account.name, ": ", account.value))


end
