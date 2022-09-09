using TestItemRunner

@testitem "General TimePeriod" begin
    struct _DummyStruct <: TimeStructure{Int} end
    struct _DummyPeriod <: TimeStruct.TimePeriod{_DummyStruct} end

    dummy = _DummyPeriod()

    @test TimeStruct._opscen(dummy) == 1
    @test TimeStruct._strat_per(dummy) == 1
    @test TimeStruct._branch(dummy) == 1
    @test_throws ErrorException TimeStruct._oper(dummy)
    @test_throws ErrorException duration(dummy)
    @test probability(dummy) == 1
    @test_throws ErrorException isfirst(dummy)
end

@testitem "SimpleTimes" begin
    day = SimpleTimes(24, 1)
    @test first(day) == TimeStruct.SimplePeriod(1, 1)
    @test length(day) == 24
    @test isfirst(TimeStruct.SimplePeriod(1, 1))
    @test first(day) < TimeStruct.SimplePeriod(3, 1)

    tops = collect(t for t in day)
    @test tops[2] == TimeStruct.SimplePeriod(2, 1)

    ts = SimpleTimes([4, 4, 4, 6, 3, 3])
    @test length(ts) == 6
    @test first(ts) == TimeStruct.SimplePeriod(1, 4)
    @test duration(first(ts)) == 4
    @test duration(ts) == 24
end

@testitem "OperationalScenarios" begin
    # 5 scenarios with 10 periods
    ts = OperationalScenarios(5, SimpleTimes(10, 1))
    @test length(ts) == length(collect(ts))

    # Iterating through operational scenarios
    scens = opscenarios(ts)
    @test length(scens) == 5
    scen_coll = collect(scens)
    @test length(scen_coll) == 5

    @test typeof(scen_coll[3]) == TimeStruct.OperationalScenario{Int}
    @test probability(scen_coll[3]) == 0.2

    @test length(scen_coll[3]) == 10
    t_coll = collect(scen_coll[3])
    @test length(t_coll) == 10

    # 3 operational scenarios, two single day and one for a week with hourly resolution
    @test sum(probability(s) for s in opscenarios(ts)) == 1.0
    day = SimpleTimes(24, 1)
    week = SimpleTimes(168, 1)
    ts = OperationalScenarios(3, [day, day, week], [0.1, 0.2, 0.7])

    @test first(ts) ==
          TimeStruct.ScenarioPeriod(1, 0.1, TimeStruct.SimplePeriod(1, 1))
    @test length(ts) == 216
    pers = []
    for sc in opscenarios(ts)
        for t in sc
            push!(pers, t)
        end
    end
    @test length(pers) == length(ts)
    @test first(pers) == first(ts)

    # Two operational scenarios, one for a day and one for a week with hourly resolution and the same probability of occuring
    ts = OperationalScenarios([day, week])

    @test first(ts) ==
          TimeStruct.ScenarioPeriod(1, 0.5, TimeStruct.SimplePeriod(1, 1))
    @test length(ts) == 192

    scens = opscenarios(ts)
    @test length(scens) == 2

    scen_coll = collect(scens)
    @test length(scen_coll) == 2

    @test typeof(scen_coll[2]) == TimeStruct.OperationalScenario{Int}
    @test probability(scen_coll[2]) == 0.5

    @test length(scen_coll[1]) == 24
end

@testitem "TwoLevel" begin
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

    ts = TwoLevel(3, 24, [day, day, day])
    @test duration(first(ts)) == 1
    @test repr(first(ts)) == "sp1-t1"
    pers = collect(ts)
    @test pers[1] < pers[2]
    @test pers[24] < pers[25]
end

@testitem "TwoLevel with units" begin
    using Unitful

    dayunit = SimpleTimes(24, 1u"hr")
    tsunit = TwoLevel([31, 28, 31, 30], u"d", dayunit)
    @test multiple(first(tsunit), tsunit) == 31
    @test duration(first(tsunit)) == 1u"hr"

    sps = strat_periods(tsunit)
    @test length(sps) == 4
    sp = first(sps)
    @test duration(sp) == 31u"d"
    @test length(sp) == 24
    @test multiple(first(sp), sp) == 31
    @test eltype(sp) <: TimeStruct.OperationalPeriod
    @test isfirst(sp)
    @test repr(sp) == "sp1"
    @test TimeStruct._strat_per(sp) == 1
end

@testitem "TwoLevel with op scenarios" begin
    day = SimpleTimes(24, 1)
    week = SimpleTimes(168, 1)
    # One year with a strategic period per quarter and 3 operational scenarios
    opscen = OperationalScenarios(3, [day, day, week], [0.1, 0.2, 0.7])
    seasonal_year = TwoLevel(24 .* [91, 91, 91, 92], opscen)
    @test length(seasonal_year) == 864

    ops = collect(seasonal_year)
    @test ops[1] == TimeStruct.OperationalPeriod(
        1,
        TimeStruct.ScenarioPeriod(1, 0.1, TimeStruct.SimplePeriod(1, 1)),
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
    scen =
        first(opscenarios(first(strat_periods(seasonal_year)), seasonal_year))
    @test repr(scen) == "sp1-sc1"
    @test probability(scen) == 0.1
    @test TimeStruct._strat_per(scen) == 1
    @test TimeStruct._opscen(scen) == 1
    per = first(scen)
    @test repr(per) == "sp1-sc1-t1"
    @test typeof(per) <: TimeStruct.OperationalPeriod{
        TimeStruct.ScenarioPeriod{TimeStruct.SimplePeriod{Int}},
    }

    # Test that operational scenarios runs without scenarios
    ts = TwoLevel(3, 10, SimpleTimes(10, 1))
    sp = first(strat_periods(ts))
    scen = first(opscenarios(sp, ts))
    @test length(scen) == 10
    @test eltype(typeof(scen)) == TimeStruct.OperationalPeriod
    @test repr(scen) == "sp1-sc1"
    @test repr(scen) == "sp1-sc1"
    @test probability(scen) == 1.0
    @test TimeStruct._strat_per(scen) == 1
    @test TimeStruct._opscen(scen) == 1
    per = first(scen)
    @test repr(per) == "sp1-t1"
    @test typeof(per) <:
          TimeStruct.OperationalPeriod{TimeStruct.SimplePeriod{Int}}

    simple = SimpleTimes(10, 2.0)
    sp = first(strat_periods(simple))
    scen = first(opscenarios(sp, simple))
    per = first(scen)
    @test typeof(per) <: TimeStruct.SimplePeriod{Float64}

    ts = OperationalScenarios(
        [SimpleTimes(5, 1.5), SimpleTimes(10, 1.0)],
        [0.9, 0.1],
    )
    pers = [
        t for sp in strat_periods(ts) for sc in opscenarios(sp, ts) for t in sc
    ]
    pers_ts = [t for t in ts]
    @test pers == pers_ts
end

@testitem "SimpleTimes as TwoLevel" begin
    simple = SimpleTimes(10, 1)
    ops1 = collect(simple)
    @test length(strat_periods(simple)) == 1
    ops2 = [t for n in strat_periods(simple) for t in n]
    @test ops1 == ops2
    per = ops2[1]
    @test typeof(per) <: TimeStruct.SimplePeriod
end

@testitem "Profiles" begin
    using Unitful
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
    @test op[TimeStruct.SimplePeriod(7, 1)] == 1
    opunit = OperationalProfile([2, 3, 4], u"m/s")
    @test opunit[TimeStruct.SimplePeriod(6, 1)] == 4u"m/s"
    opadd = op + 1
    @test sum(opadd[t] for t in day) == sum(op[t] for t in day) + 24
    opmin = op - 1
    @test sum(opmin[t] for t in day) == sum(op[t] for t in day) - 24
    opmul = 4 * op
    @test opmul[first(day)] == 8
    opdiv = op / 4.0
    @test opdiv[first(day)] == 0.5

    ts = TwoLevel(5, 168, SimpleTimes(7, 24))
    p1 = first(ts)
    @test sum(fp[t] for t in ts) == 12.0 * length(ts)

    sp1 = StrategicProfile([fp])
    @test sum(sp1[t] for t in ts) == 12.0 * length(ts)
    sp2 = StrategicProfile([op, op, fp])
    @test sum(sp2[t] for t in ts) == 2 * 11 + 3 * 84
    spadd = 1 + sp2
    @test spadd[p1] == 3
    spmin = sp2 - 3
    @test spmin[p1] == -1
    spmul = sp2 * 2
    @test spmul[p1] == 4
    spdiv = sp2 / 2
    @test spdiv[p1] == 1
    sp3 = StrategicProfile([1u"kg", 3u"kg", 5u"kg"])
    @test sp3[p1] == 1u"kg"

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
end

@testitem "TwoLevelTree" begin
    regtree = TimeStruct.regular_tree(5, [3, 2], SimpleTimes(5, 1))
    ops = [t for n in TimeStruct.strat_nodes(regtree) for t in n]
    @test length(ops) == 5 * 10
    ops2 = collect(regtree)
    @test ops == ops2

    nodes = TimeStruct.strat_nodes(regtree)
    for sp in 1:3
        @test sum(TimeStruct.probability(n) for n in nodes if n.sp == sp) ≈ 1.0
    end

    leaves = TimeStruct.leaves(regtree)
    @test length(leaves) == TimeStruct.nleaves(regtree)

    scens = collect(TimeStruct.scenarios(regtree))
    @test length(scens[2].nodes) == regtree.len
    @test scens[3].nodes[1] == regtree.nodes[1]

    ssp = TimeStruct.StrategicStochasticProfile([
        [10],
        [11, 12, 13],
        [20, 21, 22, 23, 30, 40],
    ])

    @test ssp[nodes[3]] == 20
    @test ssp[nodes[8]] == 13

    price1 = OperationalProfile([1, 2, 2, 5, 6])
    price2 = FixedProfile(4)

    dsp = TimeStruct.DynamicStochasticProfile([
        [price1],
        [price1, price2, price2],
        [price1, price2, price2, price1, price2, price2],
    ])
    @test dsp[ops[4]] == 5
end

@testitem "Iteration utilities" begin
    uniform_day = SimpleTimes(24, 1)
    uniform_week = TwoLevel(7, 24, uniform_day)

    @test first(withprev(uniform_day))[1] === nothing
    @test collect(withprev(uniform_week))[25] == (
        nothing,
        TimeStruct.OperationalPeriod(2, TimeStruct.SimplePeriod(1, 1)),
    )
end

@testitem "Discounting" begin
    uniform_years = SimpleTimes(10, 1)  # 10 years with duration of 1 year
    disc = Discounter(0.04, 1, uniform_years)

    δ = 1 / 1.04
    for (i, t) in enumerate(uniform_years)
        @test discount(disc, t) == δ^(i - 1)
    end
    return
end

@testitem "Dataframes" begin
    using DataFrames
    using Unitful
    ts = SimpleTimes(24, 1)
    df1 = DataFrame(period = [t for t in ts], value = rand(24))
    TimeStruct.expand_dataframe!(df1)
    @test df1[!, :oper_period] == [i for i in 1:24]
    @test hasproperty(df1, :duration)
    @test hasproperty(df1, :start_time)

    twolevel = TwoLevel(5, 24, OperationalScenarios(3, SimpleTimes(6, 4)))
    df2 = DataFrame(
        period = [t for t in twolevel],
        value = rand(length(twolevel)),
    )
    TimeStruct.expand_dataframe!(df2)
    @test hasproperty(df2, :strategic_period)
    @test hasproperty(df2, :op_scenario)
    @test hasproperty(df2, :oper_period)
    @test hasproperty(df2, :duration)
    @test hasproperty(df2, :start_time)

    scen = OperationalScenarios(
        5,
        SimpleTimes(4, [2.0u"hr", 3.5u"hr", 10u"hr", 20u"hr"]),
    )
    df3 = DataFrame(per = [t for t in scen], value = rand(length(scen)))
    TimeStruct.expand_dataframe!(df3)
    @test hasproperty(df3, :op_scenario)
    @test hasproperty(df3, :oper_period)
    @test hasproperty(df3, :duration)
    @test hasproperty(df3, :start_time)

    sps = strat_periods(twolevel)
    df4 = DataFrame(strat = [sp for sp in sps], val = rand(length(sps)))
    TimeStruct.expand_dataframe!(df4)
    @test hasproperty(df4, :strategic_period)
    @test hasproperty(df4, :duration)
    @test hasproperty(df4, :start_time)
end

@run_package_tests
