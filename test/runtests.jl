module RunTests

using Test
using TimeStruct
const TS = TimeStruct

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_simple_times()
    day = SimpleTimes(24, 1)
    @test first(day) == TS.SimplePeriod(1, 1)
    @test length(day) == 24
    @test isfirst(TS.SimplePeriod(1, 1))
    @test first(day) < TS.SimplePeriod(3, 1)

    tops = collect(t for t in day)
    @test tops[2] == TS.SimplePeriod(2, 1)

    ts = SimpleTimes([4, 4, 4, 6, 3, 3])
    @test length(ts) == 6
    @test first(ts) == TS.SimplePeriod(1, 4)
    @test duration(first(ts)) == 4
    @test duration(ts) == 24
    return
end

function test_stochastic()
    # 5 scenarios with 10 periods
    ts = OperationalScenarios(5, SimpleTimes(10, 1))
    @test length(ts) == length(collect(ts))

    # Iterating through operational scenarios
    scens = opscenarios(ts)
    @test length(scens) == 5
    scen_coll = collect(scens)
    @test length(scen_coll) == 5

    @test typeof(scen_coll[3]) == TS.OperationalScenario{Int}
    @test probability(scen_coll[3]) == 0.2

    @test length(scen_coll[3]) == 10
    t_coll = collect(scen_coll[3])
    @test length(t_coll) == 10

    # 3 operational scenarios, two single day and one for a week with hourly resolution
    day = SimpleTimes(24, 1)
    week = SimpleTimes(168, 1)
    ts = OperationalScenarios(3, [day, day, week], [0.1, 0.2, 0.7])

    @test first(ts) == TS.ScenarioPeriod(1, 0.1, TS.SimplePeriod(1, 1))
    @test length(ts) == 216

    @test sum(probability(s) for s in opscenarios(ts)) == 1.0

    pers = []
    for sc in opscenarios(ts)
        for t in sc
            push!(pers, t)
        end
    end
    @test length(pers) == length(ts)
    @test first(pers) == first(ts)
    return
end

function test_two_level()
    day = SimpleTimes(24, 1)
    uniform_week = TwoLevel(7, 24, day)  # 7 strategic periods, hourly resolution each day

    @test typeof(uniform_week) == TwoLevel{Int,Int}
    @test length(uniform_week) == 168

    # One year with monthly strategic periods and one day of operations for each month
    monthly_hours = 24 .* [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    uniform_year = TwoLevel(monthly_hours, day)

    @test length(uniform_year) == 12 * 24
    @test sum(sp.duration for sp in strat_periods(uniform_year)) == 8760
    @test multiple(first(uniform_year), uniform_year) == 31

    ops1 = collect(uniform_year)
    ops2 = [t for n in strat_periods(uniform_year) for t in n]

    @test ops1 == ops2
    return
end

function test_two_level_scenarios()
    day = SimpleTimes(24, 1)
    week = SimpleTimes(168, 1)
    # One year with a strategic period per quarter and 3 operational scenarios
    opscen = OperationalScenarios(3, [day, day, week], [0.1, 0.2, 0.7])
    seasonal_year = TwoLevel(24 .* [91, 91, 91, 92], opscen)
    @test length(seasonal_year) == 864

    ops = collect(seasonal_year)
    @test ops[1] == TS.OperationalPeriod(
        1,
        TS.ScenarioPeriod(1, 0.1, TS.SimplePeriod(1, 1)),
    )

    @test probability(ops[34]) == 0.2
    @test multiple(ops[34], seasonal_year) == 91

    @test probability(ops[100]) == 0.7
    @test multiple(ops[100], seasonal_year) == 13

    pers = []
    for sp in strat_periods(seasonal_year)
        for sc in opscenarios(sp, seasonal_year)
            for t in sc
                push!(pers, t)
            end
        end
    end
    @test length(pers) == length(seasonal_year)
    @test first(pers) == first(seasonal_year)

    return
end

function test_simple_two_level()
    simple = SimpleTimes(10, 1)
    ops1 = collect(simple)
    @test length(strat_periods(simple)) == 1
    ops2 = [t for n in strat_periods(simple) for t in n]
    @test ops1 == ops2
end

function test_profiles()
    day = SimpleTimes(24, 1)
    fp = FixedProfile(12.0)
    @test fp[first(day)] == 12.0

    sfp = StrategicProfile([i / 100 for i in 1:365])
    @test sfp[TS.OperationalPeriod(122, TS.SimplePeriod(1, 1))] == 1.22
    @test sfp[TS.StrategicPeriod{TwoLevel}(122, 1, SimpleTimes(24, 1))] == 1.22
    @test sfp[TS.SimplePeriod(10, 1)] == 0.01

    dp = DynamicProfile([
        OperationalProfile([i / 100 + j for j in 1:24]) for i in 1:365
    ])
    @test dp[TS.OperationalPeriod(365, TS.SimplePeriod(24, 1))] == 27.65

    scp = ScenarioProfile([
        OperationalProfile([i / 100 + j for j in 1:24]) for i in 1:5
    ])
    @test scp[TS.ScenarioPeriod(1, 1.0, TS.SimplePeriod(12, 1))] == 12.01

    scp2 = ScenarioProfile([[i / 100 + j for j in 1:24] for i in 1:5])
    @test scp2[TS.ScenarioPeriod(1, 1.0, TS.SimplePeriod(20, 1))] ==
          scp[TS.ScenarioPeriod(1, 1.0, TS.SimplePeriod(20, 1))]

    dps = DynamicProfile([
        ScenarioProfile([
            OperationalProfile([(i + j / 10 + k / 100) for i in 1:24]) for
            j in 1:10
        ]) for k in 1:5
    ])
    ts = TwoLevel(5, 24, OperationalScenarios(10, SimpleTimes(24, 1)))
    @test sum(dps[t] for t in ts) ≈ 15696.0
    @test dps[TS.OperationalPeriod(
        2,
        TS.ScenarioPeriod(2, 1.0, TS.SimplePeriod(2, 1)),
    )] == 2.22
    return
end

function test_twolevel_tree()
    regtree = TS.regular_tree(5, [3, 2], SimpleTimes(5, 1))
    ops = [t for n in TS.strat_nodes(regtree) for t in n]
    @test length(ops) == 5 * 10
    ops2 = collect(regtree)
    @test ops == ops2

    nodes = TS.strat_nodes(regtree)
    for sp in 1:3
        @test sum(TS.probability(n) for n in nodes if n.sp == sp) ≈ 1.0
    end

    leaves = TS.leaves(regtree)
    @test length(leaves) == TS.nleaves(regtree)

    scens = collect(TS.scenarios(regtree))
    @test length(scens[2].nodes) == regtree.len
    @test scens[3].nodes[1] == regtree.nodes[1]

    ssp = TS.StrategicStochasticProfile([
        [10],
        [11, 12, 13],
        [20, 21, 22, 23, 30, 40],
    ])

    @test ssp[nodes[3]] == 20
    @test ssp[nodes[8]] == 13

    price1 = OperationalProfile([1, 2, 2, 5, 6])
    price2 = FixedProfile(4)

    dsp = TS.DynamicStochasticProfile([
        [price1],
        [price1, price2, price2],
        [price1, price2, price2, price1, price2, price2],
    ])
    @test dsp[ops[4]] == 5
    return
end

function test_iter_utils()
    uniform_day = SimpleTimes(24, 1)
    uniform_week = TwoLevel(7, 24, uniform_day)

    @test first(withprev(uniform_day))[1] === nothing
    @test collect(withprev(uniform_week))[25] ==
          (nothing, TS.OperationalPeriod(2, TS.SimplePeriod(1, 1)))
    return
end

function test_discount()
    uniform_years = SimpleTimes(10, 1)  # 10 years with duration of 1 year
    disc = Discounter(0.04, 1, uniform_years)

    δ = 1 / 1.04
    for (i, t) in enumerate(uniform_years)
        @test discount(disc, t) == δ^(i - 1)
    end
    return
end

end

RunTests.runtests()
