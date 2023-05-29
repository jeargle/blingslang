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


using Dates

using Plots
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
    a2 = Account("investments", 500.00, 0.08)
    println(a2)
    println("a2: $a2")

    println("  week | value")
    for t in 2:2:52
        curr_val = value_at_time(a2, t/52.0)
        @printf "  %4d | %7.2f\n" t curr_val
    end

    println()
end

function test_account_group()
    print_test_header("AccountGroup")

    a1 = Account("bank", 1000.00)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])
    println(ag1)
    println("ag1: $ag1")

    println()
end

function test_bling_trajectory()
    print_test_header("BlingTrajectory")

    a1 = Account("bank", 1000.00)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1)
    println(bt1)
    println("bt1: $bt1")
    println("value: $(current_value(bt1))")
    println("trajectories: $(bt1.trajectories)")

    println()
end

function test_simulate()
    print_test_header("simulate()")

    a1 = Account("bank", 1000.00, 0.02)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00, 0.08)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1)

    simulate(bt1, Dates.today() + Year(1))
    println("trajectories: $(bt1.trajectories)")
    println("initial value: $(initial_value(bt1))")
    println("current value: $(current_value(bt1))")
    println("     increase: $(current_value(bt1) - initial_value(bt1))")

    println()
end

function test_plot_trajectories()
    print_test_header("plot_trajectories()")

    a1 = Account("bank", 1000.00, 0.02)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00, 0.08)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1)

    simulate(bt1, Dates.today() + Year(30))

    p = plot_trajectories(bt1)
    savefig(p, "all_values.svg")
    println("all values plotted")

    p = plot_trajectories(bt1, [a3.name])
    savefig(p, "retirement_value.svg")
    println("retirement value plotted")

    p = plot_trajectories(bt1, [:total])
    savefig(p, "total_value.svg")
    println("total value plotted")

    println()
end

function test_read_system_file()
    print_test_header("read_system_file()")

    system = read_system_file("./systems/system1.yml")
    for ag in system
        println(ag)
    end

    println()
end


function main()
    test_account()
    test_account_group()
    test_bling_trajectory()
    test_simulate()
    test_plot_trajectories()
    test_read_system_file()
end

main()
