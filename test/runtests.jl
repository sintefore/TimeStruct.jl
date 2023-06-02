using TestItemRunner

@testitem "General TimePeriod" begin
    struct _DummyStruct <: TimeStructure{Int} end
    struct _DummyPeriod <: TimeStruct.TimePeriod end

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
    @test last(ts) == last(collect(ts))
end

@testitem "SimpleTimes with units" begin
    using Unitful

    periods = SimpleTimes([24, 24, 48, 96], u"hr")
    @test duration(first(periods)) == 24u"hr"
    @test duration(periods) == 192u"hr"
end

@testitem "OperationalScenarios" begin
    # 5 scenarios with 10 periods
    ts = OperationalScenarios(5, SimpleTimes(10, 1))
    @test length(ts) == length(collect(ts))
    @test duration(ts) == 10

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
    @test_throws ErrorException last(ts)
    pers = []
    for sc in opscenarios(ts)
        @test last(sc) == last(collect(sc))
        for t in sc
            push!(pers, t)
        end
    end
    @test length(pers) == length(ts)
    @test first(pers) == first(ts)
    @test pers[1] < pers[2]
    @test isfirst(pers[25])

    # Two operational scenarios, one for a day and one for a week with hourly 
    # resolution and the same probability of occuring
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
    @test repr(scen_coll[1]) == "sc-1"

    @test length(scen_coll[1]) == 24

    # SimpleTimes as a single operational scenario
    ts = SimpleTimes(10, 1)
    pers = []
    for sc in opscenarios(ts)
        for t in sc
            push!(pers, t)
        end
    end
    @test length(pers) == length(ts)
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
    @test sum(duration(sp) for sp in strat_periods(uniform_year)) == 8760
    @test multiple(first(uniform_year)) == 31

    ops1 = collect(uniform_year)
    ops2 = [t for n in strat_periods(uniform_year) for t in n]
    @test length(ops1) == length(ops2)
    @test first(ops1) == first(ops2)
    for (i, op) in enumerate(ops1)
        @test op == ops2[i]
    end
    @test ops1 == ops2

    ts = TwoLevel(3, 24, [day, day, day])
    @test duration(first(ts)) == 1
    @test repr(first(ts)) == "sp1-t1"
    pers = collect(ts)
    @test pers[1] < pers[2]
    @test pers[24] < pers[25]

    sp = collect(strat_periods(ts))
    @test pers[length(day)] == last(sp[1])
end

@testitem "TwoLevel with units" begin
    using Unitful

    dayunit = SimpleTimes(24, 1u"hr")
    tsunit = TwoLevel([31, 28, 31, 30], u"d", dayunit)
    @test multiple(first(tsunit)) == 31
    @test duration(first(tsunit)) == 1u"hr"

    sps = strat_periods(tsunit)
    @test length(sps) == 4
    sp = first(sps)
    @test duration(sp) == 31u"d"
    @test length(sp) == 24
    @test multiple(first(sp)) == 31
    @test eltype(sp) <: TimeStruct.OperationalPeriod
    @test isfirst(sp)
    @test repr(sp) == "sp1"
    @test TimeStruct._strat_per(sp) == 1
end

@testitem "TwoLevel scaling" begin
    day = SimpleTimes(24, 1)
    years = [2, 2, 5, 5]
    study_period = TwoLevel(years, day; op_per_strat = 8760)

    t = first(study_period)
    @test multiple(t) == 2 * 365

    for (y, sp) in enumerate(strategic_periods(study_period))
        for t in sp
            @test multiple(t) == 365 * years[y]
        end
    end
end

@testitem "TwoLevel accumulated" begin
    day = SimpleTimes(24, 1)
    study_period = TwoLevel([2, 2, 5, 10], day)

    start_t = [0, 2, 4, 9]
    end_t = [2, 4, 9, 19]
    for (y, sp) in enumerate(strategic_periods(study_period))
        @test start_time(sp, study_period) == start_t[y]
        @test end_time(sp, study_period) == end_t[y]
        @test remaining(sp, study_period) == 19 - start_t[y]
    end

    using Unitful
    start_t = [0, 1, 3] .* 1u"d"
    end_t = [1, 3, 7] .* 1u"d"
    study_period = TwoLevel([1u"d", 2u"d", 4u"d"], SimpleTimes(24, 1u"hr"))
    for (y, sp) in enumerate(strategic_periods(study_period))
        @test start_time(sp, study_period) == start_t[y]
        @test end_time(sp, study_period) == end_t[y]
    end
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
        91.0,
    )

    @test probability(ops[34]) == 0.2
    @test multiple(ops[34]) == 91

    @test probability(ops[100]) == 0.7
    @test multiple(ops[100]) == 13

    pers = []
    for sp in strat_periods(seasonal_year)
        for sc in opscenarios(sp)
            @test last(collect(sc)) == last(sc)
            for t in sc
                push!(pers, t)
            end
        end
    end

    pers_sp = []
    for sp in strat_periods(seasonal_year)
        for t in sp
            push!(pers_sp, t)
        end
    end
    @test issetequal(pers, pers_sp)

    @test sum(length(opscenarios(sp)) for sp in strat_periods(seasonal_year)) ==
          12
    @test length(pers) == length(seasonal_year)
    @test typeof(first(pers)) == typeof(first(seasonal_year))
    scen = first(opscenarios(first(strat_periods(seasonal_year))))
    @test repr(scen) == "sp1-sc1"
    @test probability(scen) == 0.1
    @test TimeStruct._strat_per(scen) == 1
    @test TimeStruct._opscen(scen) == 1
    per = first(scen)
    @test repr(per) == "sp1-sc1-t1"
    @test typeof(per) <: TimeStruct.OperationalPeriod

    # Test that operational scenarios runs without scenarios
    ts = TwoLevel(3, 10, SimpleTimes(10, 1))
    sp = first(strat_periods(ts))
    scen = first(opscenarios(sp))
    @test length(scen) == 10
    @test eltype(typeof(scen)) == TimeStruct.OperationalPeriod
    @test repr(scen) == "sp1-sc1"
    @test probability(scen) == 1.0
    @test TimeStruct._strat_per(scen) == 1
    @test TimeStruct._opscen(scen) == 1
    per = first(scen)
    @test repr(per) == "sp1-t1"
    @test typeof(per) <: TimeStruct.OperationalPeriod

    simple = SimpleTimes(10, 2.0)
    sp = first(strat_periods(simple))
    scen = first(opscenarios(sp))
    per = first(scen)
    @test typeof(per) <: TimeStruct.SimplePeriod{Float64}

    ts = OperationalScenarios(
        [SimpleTimes(5, 1.5), SimpleTimes(10, 1.0)],
        [0.9, 0.1],
    )
    pers = [t for sp in strat_periods(ts) for sc in opscenarios(sp) for t in sc]
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

    ops3 = [t for sc in opscenarios(simple) for t in sc]
    @test ops1 == ops3
end

@testitem "OperationalScenarios as TwoLevel" begin
    opscens = OperationalScenarios([SimpleTimes(10, 1), SimpleTimes(5, 2)])
    ops1 = collect(opscens)
    @test length(strat_periods(opscens)) == 1
    ops2 = [t for n in strat_periods(opscens) for t in n]
    @test ops1 == ops2
    per = ops2[1]
    @test typeof(per) <: TimeStruct.ScenarioPeriod
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

    op = ops[31]
    @test TimeStruct._opscen(op) == 1
    @test TimeStruct._strat_per(op) == 3
    @test TimeStruct._branch(op) == 4
    @test TimeStruct._oper(op) == 1
    @test duration(op) == 1
    @test probability(op) == 1 / 6
    @test typeof(op) == eltype(typeof(regtree))

    nodes = strat_nodes(regtree)
    for sp in 1:3
        @test sum(probability(n) for n in nodes if n.sp == sp) ≈ 1.0
    end
    node = nodes[2]
    @test length(node) == 5
    @test typeof(first(node)) == eltype(typeof(node))

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

@testitem "TwoLevelTree and opscenarios" begin
    regtree = TimeStruct.regular_tree(
        5,
        [3, 2],
        OperationalScenarios(3, SimpleTimes(5, 1)),
    )

    ops1 = collect(regtree)
    ops2 = [
        t for sp in strat_periods(regtree) for sc in opscenarios(sp) for t in sc
    ]
    @test length(ops1) == length(ops2)
    for (i, op) in enumerate(ops1)
        @test op == ops2[i]
    end

    @test sum(length(opscenarios(sp)) for sp in strat_periods(regtree)) == 30
    @test sum(
        length(sc) for sp in strat_periods(regtree) for sc in opscenarios(sp)
    ) == 150

    sregtree = TimeStruct.regular_tree(5, [3, 2], SimpleTimes(5, 1))
    ops1 = collect(sregtree)
    ops2 = [
        t for sp in strat_periods(sregtree) for sc in opscenarios(sp) for
        t in sc
    ]
    @test length(ops1) == length(ops2)
    @test ops1 == ops2

    @test sum(length(opscenarios(sp)) for sp in strat_periods(sregtree)) == 10
    @test sum(
        length(sc) for sp in strat_periods(sregtree) for sc in opscenarios(sp)
    ) == 50
end

@testitem "Strategic scenarios" begin
    regtree = TimeStruct.regular_tree(
        5,
        [3, 2],
        OperationalScenarios(3, SimpleTimes(5, 1)),
    )

    @test length(scenarios(regtree)) == 6

    for sc in scenarios(regtree)
        @test length(sc) == length(collect(sc))

        for (prev_sp, sp) in withprev(sc)
            if !isnothing(prev_sp)
                @test TimeStruct._strat_per(prev_sp) + 1 ==
                      TimeStruct._strat_per(sp)
            end
        end
    end
end

@testitem "TwoLevel as a tree" begin
    two_level = TwoLevel(5, 10, SimpleTimes(10, 1))

    scens = scenarios(two_level)
    @test length(scens) == 1
    sps = collect(sp for sc in scenarios(two_level) for sp in strat_periods(sc))
    @test length(sps) == 5
end

@testitem "Iteration utilities" begin
    uniform_day = SimpleTimes(24, 1)
    uniform_week = TwoLevel(7, 24, uniform_day)

    @test first(withprev(uniform_day))[1] === nothing
    @test collect(withprev(uniform_week))[25] == (
        nothing,
        TimeStruct.OperationalPeriod(2, TimeStruct.SimplePeriod(1, 1), 1.0),
    )
end

@testitem "Discounting" begin
    using Unitful

    uniform_years = TwoLevel(10, 1, SimpleTimes(1, 1))  # 10 years with duration of 1 year
    disc = Discounter(0.04, 1, uniform_years)

    δ = 1 / 1.04
    for (i, t) in enumerate(uniform_years)
        @test discount(disc, t) == δ^(i - 1)
    end

    @test sum(objective_weight(t, disc) for t in uniform_years) ≈ 8.435 atol =
        1e-3

    uniform_day = SimpleTimes(24, 1)
    periods = TwoLevel(10, 8760, uniform_day)
    disc_hour = Discounter(0.04, 1 / 8760, periods)

    @test sum(
        objective_weight(sp, disc_hour) for sp in strat_periods(periods)
    ) ≈ 8.435 atol = 1e-3

    uniform_day = SimpleTimes(24, 1u"hr")
    periods_unit = TwoLevel(10, 365.125u"d", uniform_day)
    disc_unit = Discounter(0.04, periods_unit)

    @test sum(
        objective_weight(sp, disc_unit) for sp in strat_periods(periods_unit)
    ) ≈ 8.435 atol = 1e-3
end

@testitem "Start and end times" begin
    using Unitful

    uniform_day = SimpleTimes(24, 1)
    periods = TwoLevel(10, 8760, uniform_day)

    start_t = collect(start_oper_time(t, periods) for t in periods)
    end_t = collect(end_oper_time(t, periods) for t in periods)
    @test start_t[26] == end_t[25]

    uniform_day = SimpleTimes(24, 1u"hr")
    periods_unit = TwoLevel(10, 365.125u"d", uniform_day)
    start_t = collect(start_oper_time(t, periods_unit) for t in periods_unit)
    end_t = collect(end_oper_time(t, periods_unit) for t in periods_unit)
    @test start_t[26] == end_t[25]

    tsc =
        TwoLevel(3, 168u"hr", OperationalScenarios(3, SimpleTimes(7, 24u"hr")))
    start_t = collect(start_oper_time(t, tsc) for t in tsc)
    end_t = collect(end_oper_time(t, tsc) for t in tsc)

    @test start_t[1] == 0u"hr"
    @test end_t[1] == 24u"hr"
    @test start_t[9] == end_t[8]
end

@testitem "Dataframes" begin
    using DataFrames
    using Unitful
    ts = SimpleTimes(24, 1)
    df1 = DataFrame(period = [t for t in ts], value = rand(24))
    TimeStruct.expand_dataframe!(df1, ts)
    @test df1[!, :oper_period] == [i for i in 1:24]
    @test hasproperty(df1, :duration)
    @test hasproperty(df1, :start_time)
    @test hasproperty(df1, :end_time)

    twolevel = TwoLevel(5, 24, OperationalScenarios(3, SimpleTimes(6, 4)))
    df2 = DataFrame(
        period = [t for t in twolevel],
        value = rand(length(twolevel)),
    )
    TimeStruct.expand_dataframe!(df2, twolevel)
    @test hasproperty(df2, :strategic_period)
    @test hasproperty(df2, :op_scenario)
    @test hasproperty(df2, :oper_period)
    @test hasproperty(df2, :duration)
    @test hasproperty(df2, :start_oper_time)
    @test hasproperty(df2, :end_oper_time)

    scen = OperationalScenarios(
        5,
        SimpleTimes(4, [2.0u"hr", 3.5u"hr", 10u"hr", 20u"hr"]),
    )
    df3 = DataFrame(per = [t for t in scen], value = rand(length(scen)))
    TimeStruct.expand_dataframe!(df3, scen)
    @test hasproperty(df3, :op_scenario)
    @test hasproperty(df3, :oper_period)
    @test hasproperty(df3, :duration)
    @test hasproperty(df3, :start_time)
    @test hasproperty(df3, :end_time)

    sps = strat_periods(twolevel)
    df4 = DataFrame(strat = [sp for sp in sps], val = rand(length(sps)))
    TimeStruct.expand_dataframe!(df4, twolevel)
    @test hasproperty(df4, :strategic_period)
    @test hasproperty(df4, :duration)
    @test hasproperty(df4, :start_time)
end

@run_package_tests
