# John Eargle (mailto: jeargle at gmail.com)
# 2023
# test
#
# To build sysimage boom.so from blingslang/test:
#   using PackageCompiler
#   create_sysimage([:Plots, :Printf, :Random], sysimage_path="../boom.so", precompile_execution_file="so_builder.jl")
#
# To run from uveldt/test:
#   julia --project=.. -J../boom.so test.jl


using Printf
using blingslang


function print_test_header(test_name)
    border = repeat("*", length(test_name) + 4)
    println(border)
    println("* ", test_name, " *")
    println(border)
end

function test_account()
    print_test_header("Account")
    a1 = Account("bank", 1000.00)
    println(a1)
    println("a1: $a1")
end

function test_account_group()
    print_test_header("AccountGroup")
    a1 = Account("bank", 1000.00)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])
    println(ag1)
    println("ag1: $ag1")
end


function main()
    test_account()
    test_account_group()
end

main()
