# John Eargle (mailto: jeargle at gmail.com)
# test
#
# To build sysimage boom.so from blingslang/test:
#   using PackageCompiler
#   create_sysimage([:Plots, :Printf, :Random], sysimage_path="../boom.so", precompile_execution_file="so_builder.jl")
#
# To run from blingslang/test:
#   julia --project=.. -J../boom.so test.jl


using Dates

using Plots
using Printf
using Test

using blingslang


function print_test_header(test_name)
    border = repeat("*", length(test_name) + 4)
    println(border)
    println("* ", test_name, " *")
    println(border)
end

function test_account_update()
    print_test_header("AccountUpdate")

    au1 = AccountUpdate(100.0, "once", "2020-04-01")
    println(au1)
    println("au1: $au1")
    @test au1.value_change == 100.0
    @test au1.recurrence == "once"
    @test au1.day == 0
    @test au1.next_date == Date("2020-04-01")


    au2 = AccountUpdate(1500.0, "weekly", "Thursday")
    println("au2: $au2")
    @test au2.value_change == 1500.0
    @test au2.recurrence == "weekly"
    @test au2.day == 4
    # @test au1.next_date == Date("2020-04-01")

    au3 = AccountUpdate(-2500.0, "monthly", "3")
    println("au3: $au3")
    @test au3.value_change == -2500.0
    @test au3.recurrence == "monthly"
    @test au3.day == 3

    au4 = AccountUpdate(-2400.0, "yearly", "3")
    println("au4: $au4")
    @test au4.value_change == -2400.0
    @test au4.recurrence == "yearly"
    @test au4.day == 3

    au5 = AccountUpdate(-5.0, "daily")
    println("au5: $au5")
    @test au5.value_change == -5.0
    @test au5.recurrence == "daily"
    @test au5.day == 0

    au6 = AccountUpdate(-2300.0, "monthly", 3)
    println("au6: $au6")
    @test au6.value_change == -2300.0
    @test au6.recurrence == "monthly"
    @test au6.day == 3

    au7 = AccountUpdate(-2200.0, "yearly", 3)
    println("au7: $au7")
    @test au7.value_change == -2200.0
    @test au7.recurrence == "yearly"
    @test au7.day == 3

    println()
end

function test_account()
    print_test_header("Account")

    a1 = Account("bank", 5000.00)
    println(a1)
    println("a1: $a1")

    a2 = Account("investments", 500.00, 0.08)
    println("a2: $a2")

    println("  week | value")
    for t in 2:2:52
        curr_val = value_at_time(a2, t/52.0)
        @printf "  %4d | %7.2f\n" t curr_val
    end

    au1 = AccountUpdate(100.0, "once", "2020-04-01")
    println("au1: $au1")

    au2 = AccountUpdate(1500.0, "weekly", "Thursday")
    println("au2: $au2")

    au3 = AccountUpdate(-2500.0, "monthly", 3)
    println("au3: $au3")

    a3 = Account("investments", 500.00, [au1, au2, au3])
    println("a3: $a3")
    println("a3.updates: $(a3.updates)")

    println()
end

function test_account_group()
    print_test_header("AccountGroup")

    a1 = Account("bank", 5000.00)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])
    println(ag1)
    println("ag1: $ag1")

    println()
end

function test_account_dag()
    print_test_header("AccountDag")

    a1 = Account("bank", 5000.00)
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    a4 = Account("vacation", 10000.00)
    nodes = [a1, a2, a3, a4]
    edges = [(a1, a2), (a2, a3), (a1, a4)]
    ad1 = AccountDag(nodes, edges)

    println("ad1.children[a1]:")
    println(ad1.children[a1])
    println("ad1.parents[a2]:")
    println(ad1.parents[a2])

    println()
end

function test_bling_trajectory()
    print_test_header("BlingTrajectory")

    au1 = AccountUpdate(1200.0, "weekly", "Friday")
    au2 = AccountUpdate(-2600.0, "monthly", 3)
    a1 = Account("bank", 5000.00, [au1, au2])
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1, Dates.today() + Year(1))
    println(bt1)
    println("bt1: $bt1")
    println("value: $(current_value(bt1))")
    println("trajectories: $(bt1.trajectories)")

    println()
end

function test_simulate()
    print_test_header("simulate()")

    au1 = AccountUpdate(1200.0, "weekly", "Friday")
    au2 = AccountUpdate(-2600.0, "monthly", 3)
    a1 = Account("bank", 5000.00, [au1, au2])
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 60000.00, 0.08)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1, Dates.today() + Year(1))

    simulate(bt1)
    println("trajectories: $(bt1.trajectories)")
    println("initial value: $(initial_value(bt1))")
    println("current value: $(current_value(bt1))")
    println("     increase: $(current_value(bt1) - initial_value(bt1))")

    println()
end

function test_plot_trajectories()
    print_test_header("plot_trajectories()")

    au1 = AccountUpdate(1200.0, "weekly", "Friday")
    au2 = AccountUpdate(-2600.0, "monthly", 3)
    a1 = Account("bank", 5000.00, [au1, au2])
    a2 = Account("house", 250000.00)
    a3 = Account("retirement", 140000.00, 0.08)
    ag1 = AccountGroup("net_worth", [a1, a2, a3])

    bt1 = BlingTrajectory("household", ag1, Dates.today() + Year(30))

    simulate(bt1)

    p = plot_trajectories(bt1)
    savefig(p, "all_values.svg")
    println("all values plotted")

    p = plot_trajectories(bt1, account_names=[a1.name])
    savefig(p, "bank_value.svg")
    println("bank value plotted")

    p = plot_trajectories(bt1, account_names=[a3.name])
    savefig(p, "retirement_value.svg")
    println("retirement value plotted")

    p = plot_trajectories(bt1, account_names=["total"])
    savefig(p, "total_value.svg")
    println("total value plotted")

    println()
end

function test_read_system_file()
    print_test_header("read_system_file()")

    system = read_system_file("./systems/system1.yml")
    for ag in system["account_groups"]
        println(ag)
    end

    println()
end

function test_read_file_and_simulate()
    print_test_header("Read File and Simulate")

    system = read_system_file("./systems/system1.yml")
    bt1 = system["trajectories"]["net worth"]
    simulate(bt1)

    for plot in system["plots"]
        file_name = plot["file_name"]
        traj = system["trajectories"][plot["trajectory"]]
        account_names = plot["account_names"]
        if length(account_names) > 0
            p = plot_trajectories(traj, account_names=account_names)
        else
            p = plot_trajectories(traj)
        end
        savefig(p, file_name)
        println("$(file_name) plotted")
    end

    println()
end


function main()
    test_account_update()
    test_account()
    test_account_group()
    test_account_dag()

    test_bling_trajectory()
    test_simulate()

    test_plot_trajectories()
    test_read_system_file()
    test_read_file_and_simulate()
end

main()
