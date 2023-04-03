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


function main()
    test_account()
end

main()
