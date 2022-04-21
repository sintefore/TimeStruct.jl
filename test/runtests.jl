module RunTests

using Test
using TimeStruct
using Unitful
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

struct _DummyStruct <: TimeStructure{Int} end
struct _DummyPeriod <: TS.TimePeriod{_DummyStruct} end

function test_timeperiod()
    dummy = _DummyPeriod()

    @test TS._opscen(dummy) == 1
    @test TS._strat_per(dummy) == 1
    @test TS._branch(dummy) == 1
    @test_throws ErrorException TS._oper(dummy)
    @test_throws ErrorException duration(dummy)
    @test probability(dummy) == 1
    @test_throws ErrorException isfirst(dummy)
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

    fp = FixedProfile(12)
    @test fp[first(day)] == 12
    @test sum(fp[t] for t in day) == 12 * 24
    fpadd = fp + 4
    @test sum(fpadd[t] for t in day) == 16 * 24
    fpsub = fp - 3
    @test sum(fpsub[t] for t in day) == 9 * 24
    fpmul = 2 * fp
    @test sum(fpmul[t] for t in day) == 24 * 24
    fpdiv = fp / 4
    @test sum(fpdiv[t] for t in day) == 3 * 24
    fpunit = FixedProfile(12, u"kg")
    @test fpunit[first(day)] == 12u"kg"

    op = OperationalProfile([2, 2, 2, 2, 1])
    @test sum(op[t] for t in day) == 4 * 2 + 20 * 1
    @test op[TS.SimplePeriod(7, 1)] == 1
    opunit = OperationalProfile([2, 3, 4], u"m/s")
    @test opunit[TS.SimplePeriod(6, 1)] == 4u"m/s"
    opadd = op + 1
    @test sum(opadd[t] for t in day) == sum(op[t] for t in day) + 24
    opmin = op - 1
    @test sum(opmin[t] for t in day) == sum(op[t] for t in day) - 24
    opmul = 4 * op
    @test opmul[first(day)] == 8
    opdiv = op / 4.0
    @test opdiv[first(day)] == 0.5

    ts = TwoLevel(5, 168, SimpleTimes(7, 24))
    @test sum(fp[t] for t in ts) == 12.0 * length(ts)

    sp1 = StrategicProfile([fp])
    @test sum(sp1[t] for t in ts) == 12.0 * length(ts)
    sp2 = StrategicProfile([op, op, fp])
    @test sum(sp2[t] for t in ts) == 2 * 11 + 3 * 84
    spadd = 1 + sp2
    @test spadd[first(ts)] == 3
    spmin = sp2 - 3
    @test spmin[first(ts)] == -1
    spmul = sp2 * 2
    @test spmul[first(ts)] == 4
    spdiv = sp2 / 2
    @test spdiv[first(ts)] == 1

    tsc = TwoLevel(3, 168, OperationalScenarios(3, SimpleTimes(7, 24)))
    @test sum(fp[t] for t in tsc) == 12.0 * length(tsc)
    scp = ScenarioProfile([op, 2 * op, 3 * op])
    @test sum(scp[t] for t in tsc) == 3 * (11 + 2 * 11 + 3 * 11)

    scp2 = ScenarioProfile([[1, 1, 2], [3], [4, 5]])
    @test sum(scp2[t] for t in tsc) == 201

    ssp = StrategicProfile([scp, scp2])
    @test sum(ssp[t] for t in tsc) == 200

    sspadd = ssp + 1
    @test sum(sspadd[t] for t in tsc) == 200 + length(tsc)
    sspmin = ssp - 1
    @test sum(sspmin[t] for t in tsc) == 200 - length(tsc)
    sspmul = ssp * 2.5
    @test sum(sspmul[t] for t in tsc) == 200 * 2.5
    sspdiv = ssp / 0.5
    @test sum(sspdiv[t] for t in tsc) == 200 / 0.5

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
