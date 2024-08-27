using TestItemRunner
using TimeStruct
using Aqua

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
    @test TimeStruct._total_duration(ts) == 24

    @test_throws ArgumentError SimpleTimes(15, [4, 4, 4, 6, 3, 3])
end

@testitem "SimpleTimes with units" begin
    using Unitful

    periods = SimpleTimes([24, 24, 48, 96], u"hr")
    @test duration(first(periods)) == 24u"hr"
    @test TimeStruct._total_duration(periods) == 192u"hr"
end

@testitem "CalendarTimes" begin
    using Dates
    using TimeZones

    year = CalendarTimes(DateTime(2024, 1, 1), 12, Month(1))
    @test length(year) == 12

    @test first(year) == TimeStruct.CalendarPeriod(
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 1),
        1,
    )
    @test TimeStruct._total_duration(year) == 366 * 24

    months = collect(year)
    @test duration(months[2]) == 29 * 24

    # 10 weeks with reduced length due to DST
    periods =
        CalendarTimes(DateTime(2023, 3, 1), tz"Europe/Berlin", 10, Week(1))
    dur = [duration(w) for w in periods]
    @test TimeStruct._total_duration(periods) == 10 * 168 - 1
    @test dur[4] == 167

    # 10 weeks not affected by DST
    periods =
        CalendarTimes(DateTime(2023, 4, 1), tz"Europe/Berlin", 10, Week(1))
    dur = [duration(w) for w in periods]
    @test TimeStruct._total_duration(periods) == 10 * 168
    @test dur[4] == 168

    hours = CalendarTimes(
        DateTime(2023, 3, 25),
        DateTime(2023, 3, 26),
        tz"Europe/Berlin",
        Hour(1),
    )
    @test TimeStruct._total_duration(hours) == 24

    hours = CalendarTimes(
        DateTime(2023, 3, 26),
        DateTime(2023, 3, 27),
        tz"Europe/Berlin",
        Hour(1),
    )
    @test TimeStruct._total_duration(hours) == 23

    days = CalendarTimes(Date(2023, 10, 1), Date(2023, 10, 27), Day(2))
    @test TimeStruct._total_duration(days) == 13 * 48
end

@testitem "OperationalScenarios" begin
    # 5 scenarios with 10 periods
    ts = OperationalScenarios(5, SimpleTimes(10, 1))
    @test length(ts) == length(collect(ts))
    @test TimeStruct._total_duration(ts) == 10

    # Iterating through operational scenarios
    scens = opscenarios(ts)
    @test length(scens) == 5
    scen_coll = collect(scens)
    @test length(scen_coll) == 5

    @test typeof(scen_coll[3]) ==
          TimeStruct.OperationalScenario{Int,SimpleTimes{Int}}
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
          TimeStruct.ScenarioPeriod(1, 0.1, 7.0, TimeStruct.SimplePeriod(1, 1))
    @test length(ts) == 216
    pers = []
    for sc in opscenarios(ts)
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
          TimeStruct.ScenarioPeriod(1, 0.5, 7.0, TimeStruct.SimplePeriod(1, 1))
    @test length(ts) == 192

    scens = opscenarios(ts)
    @test length(scens) == 2

    scen_coll = collect(scens)
    @test length(scen_coll) == 2

    @test typeof(scen_coll[2]) ==
          TimeStruct.OperationalScenario{Int,SimpleTimes{Int}}
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

    # Testing the internal constructor
    @test_throws ArgumentError OperationalScenarios(2, [day, week], [1.0])
    @test_throws ArgumentError OperationalScenarios(2, [day], [0.5, 0.5])
    msg =
        "The sum of the probablity vector is given by $(2.0). " *
        "This can lead to unexpected behaviour."
    @test_logs (:warn, msg) OperationalScenarios([day, day], [0.5, 1.5])
end

@testitem "RepresentativePeriods" begin
    rep = RepresentativePeriods(
        2,
        8760,
        [0.4, 0.6],
        [SimpleTimes(24, 1), SimpleTimes(24, 1)],
    )
    @test length(rep) == length(collect(rep))
    @test TimeStruct._total_duration(rep) == 8760

    # SimpleTimes as one representative period
    simple = SimpleTimes(10, 1)
    pers = [t for rp in repr_periods(simple) for t in rp]
    @test pers == collect(simple)
    @test sum(duration(t) * multiple(t) for t in pers) == 10

    # Testing the internal constructor
    day = SimpleTimes(24, 1)
    @test_throws ArgumentError RepresentativePeriods(2, 8760, [1.0], [day, day])
    @test_throws ArgumentError RepresentativePeriods(2, 8760, [0.5, 0.5], [day])
    msg =
        "The sum of the `period_share` vector is given by $(2.0). " *
        "This can lead to unexpected behaviour."
    @test_logs (:warn, msg) RepresentativePeriods(8760, [0.5, 1.5], [day, day])

    # Testing of the external constructors providing the same case
    ts_1 = RepresentativePeriods(2, 8760, [0.5, 0.5], [day, day])
    ts_2 = RepresentativePeriods(2, 8760, day)
    ts_3 = RepresentativePeriods(8760, [0.5, 0.5], [day, day])
    ts_4 = RepresentativePeriods(8760, [day, day])
    ts_5 = RepresentativePeriods(8760, [0.5, 0.5], day)

    fields = fieldnames(typeof(ts_1))
    @test sum(
        getfield(ts_1, field) == getfield(ts_2, field) for field in fields
    ) == length(fields)
    @test sum(
        getfield(ts_1, field) == getfield(ts_3, field) for field in fields
    ) == length(fields)
    @test sum(
        getfield(ts_1, field) == getfield(ts_4, field) for field in fields
    ) == length(fields)
    @test sum(
        getfield(ts_1, field) == getfield(ts_5, field) for field in fields
    ) == length(fields)
end

@testitem "RepresentativePeriods with units" begin
    using Unitful

    rep = RepresentativePeriods(
        2,
        1u"yr",
        [0.4, 0.6],
        [SimpleTimes(24, 1u"hr"), SimpleTimes(24, 1u"hr")],
    )

    mult1 = [multiple(t) for t in rep]
    mult2 = [multiple(t) for rp in repr_periods(rep) for t in rp]

    @test mult1 == mult2
end

@testitem "RepresentativePeriods with OperationalScenarios" begin
    day = SimpleTimes(1, 1)
    week = SimpleTimes(7, 1)
    scenarios = OperationalScenarios(2, [day, week], [0.1, 0.9])

    rep = RepresentativePeriods(2, 28, [0.7, 0.3], [scenarios, scenarios])

    @test sum(probability(t) * multiple(t) * duration(t) for t in rep) ≈ 28
    @test sum(
        probability(t) * multiple(t) * duration(t) for rp in repr_periods(rep)
        for t in rp
    ) ≈ 28
    @test sum(
        probability(t) * multiple(t) * duration(t) for rp in repr_periods(rep)
        for sc in opscenarios(rp) for t in sc
    ) ≈ 28

    pers = collect(rep)
    pers_rep = collect(t for rp in repr_periods(rep) for t in rp)
    pers_scen = collect(
        t for rp in repr_periods(rep) for sc in opscenarios(rp) for t in sc
    )

    @test pers == pers_rep
    @test pers == pers_scen

    @test [multiple(t) for t in pers] == [multiple(t) for t in pers_rep]
    @test [multiple(t) for t in pers] == [multiple(t) for t in pers_scen]

    # Without operational scenarios
    rep_simple = RepresentativePeriods(2, 28, [0.7, 0.3], [day, week])

    pers = collect(rep_simple)
    pers_rep = collect(t for rp in repr_periods(rep_simple) for t in rp)
    pers_scen = collect(
        t for rp in repr_periods(rep_simple) for sc in opscenarios(rp) for
        t in sc
    )

    @test pers == pers_rep
    @test pers == pers_scen

    @test [multiple(t) for t in pers] == [multiple(t) for t in pers_rep]
    @test [multiple(t) for t in pers] == [multiple(t) for t in pers_scen]

    # Test with only OperationalScenarios
    pers = collect(scenarios)
    pers_rep = collect(t for rp in repr_periods(scenarios) for t in rp)
    pers_scen = collect(
        t for rp in repr_periods(scenarios) for sc in opscenarios(rp) for
        t in sc
    )

    # Test with just SimpleTimes
    simple = SimpleTimes(10, 1)

    pers = collect(simple)
    pers_rep = collect(t for rp in repr_periods(simple) for t in rp)
    pers_scen = collect(
        t for rp in repr_periods(simple) for sc in opscenarios(rp) for t in sc
    )

    @test pers == pers_rep
    @test pers == pers_scen
end

@testitem "RepresentativePeriods and OperationalScenarios with units" begin
    using Unitful

    day = SimpleTimes(1, 1u"d")
    week = SimpleTimes(7, 1u"d")
    scenarios = OperationalScenarios(2, [day, week], [0.1, 0.9])

    rep = RepresentativePeriods(2, 10u"wk", [0.7, 0.3], [scenarios, scenarios])

    @test sum(probability(t) * duration(t) * multiple(t) for t in rep) ≈ 70u"d"
    @test sum(
        probability(t) * duration(t) * multiple(t) for rp in repr_periods(rep)
        for t in rp
    ) ≈ 70u"d"
    @test sum(
        probability(t) * duration(t) * multiple(t) for rp in repr_periods(rep)
        for sc in opscenarios(rp) for t in sc
    ) ≈ 70u"d"
end

@testitem "TwoLevel" begin
    day = SimpleTimes(24, 1)
    uniform_week = TwoLevel(7, 24, day)  # 7 strategic periods, hourly resolution each day

    @test typeof(uniform_week) == TwoLevel{Int,Int,SimpleTimes{Int}}
    @test length(uniform_week) == 168

    # One year with monthly strategic periods and one day of operations for each month
    monthly_hours = 24 .* [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    uniform_year = TwoLevel(monthly_hours, day)

    @test length(uniform_year) == 12 * 24
    @test sum(duration_strat(sp) for sp in strat_periods(uniform_year)) == 8760
    @test multiple(first(uniform_year)) == 31

    ops1 = collect(uniform_year)
    ops2 = [t for n in strat_periods(uniform_year) for t in n]
    @test length(ops1) == length(ops2)
    @test first(ops1) == first(ops2)
    for (i, op) in enumerate(ops1)
        @test op == ops2[i]
    end
    @test ops1 == ops2

    ts = TwoLevel([day, day, day])
    @test duration(first(ts)) == 1
    @test repr(first(ts)) == "sp1-t1"
    pers = collect(ts)
    @test pers[1] < pers[2]
    @test pers[24] < pers[25]

    sp = collect(strat_periods(ts))

    # Test that collect is working correctly
    ops = collect(sp[1])
    @test sum(ops[it] == op for (it, op) in enumerate(sp[1])) == 24
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
    @test duration_strat(sp) == 31u"d"
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
        @test remaining(sp, strat_periods(study_period)) == 19 - start_t[y]
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

@testitem "TwoLevel with CalendarTimes" begin
    using Dates
    years = TwoLevel([
        CalendarTimes(DateTime(y, 1, 1), 12, Month(1)) for y in 2023:2032
    ])

    @test length(years) == length(collect(years))

    dur = [duration_strat(sp) for sp in strat_periods(years)]
    @test dur[2] == 366 * 24

    sp = first(strat_periods(years))
    mths = collect(sp)

    m = mths[4]
    @test TimeStruct._oper(m) == 4
    @test duration(m) == 30 * 24
    @test TimeStruct.start_date(m.period) == DateTime(2023, 4, 1)

    scens = OperationalScenarios(
        4,
        CalendarTimes(DateTime(2023, 9, 1), 10, Hour(1)),
    )
    ts = TwoLevel(5, 1, scens; op_per_strat = 8760)

    pers = collect(ts)
    per = pers[52]

    @test typeof(per) <: TimeStruct.OperationalPeriod
    @test TimeStruct._oper(per) == 2
    @test TimeStruct._strat_per(per) == 2
    @test TimeStruct._opscen(per) == 2

    @test multiple(per) == 8760 / 10
    @test probability(per) == 0.25
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
        TimeStruct.ScenarioPeriod(1, 0.1, 7.0, TimeStruct.SimplePeriod(1, 1)),
        91.0,
    )

    @test probability(ops[34]) == 0.2
    @test multiple(ops[34]) == 91

    @test probability(ops[100]) == 0.7
    @test multiple(ops[100]) == 13

    pers = []
    for sp in strat_periods(seasonal_year)
        for sc in opscenarios(sp)
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
    #@test probability(scen) == 0.1
    per = first(scen)
    @test repr(per) == "sp1-sc1-t1"
    @test typeof(per) <: TimeStruct.OperationalPeriod

    # Test that collect is working correctly
    sps = collect(strat_periods(seasonal_year))
    ops = collect(sps[1])
    @test sum(ops[it] == op for (it, op) in enumerate(sps[1])) == 24 + 24 + 168

    # Test that operational scenarios runs without scenarios
    ts = TwoLevel(3, 10, SimpleTimes(10, 1))
    sp = first(strat_periods(ts))
    scen = first(opscenarios(sp))
    @test length(scen) == 10
    @test eltype(typeof(scen)) == TimeStruct.OperationalPeriod
    @test repr(scen) == "sp1-sc1"
    @test probability(scen) == 1.0
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

@testitem "TwoLevel with RepresentativePeriods and OperationalScenarios" begin
    day = SimpleTimes(24, 1)
    week = SimpleTimes(168, 1)

    opscen_summer = OperationalScenarios(3, [day, day, week], [0.1, 0.2, 0.7])
    opscen_winter = OperationalScenarios(2, [day, week], [0.1, 0.9])

    ts = TwoLevel(
        3,
        5 * 8760,
        RepresentativePeriods(
            2,
            8760,
            [0.7, 0.3],
            [opscen_summer, opscen_winter],
        );
        op_per_strat = 1.0,
    )

    pers = collect(ts)
    @test length(pers) == length(ts)

    total_dur = sum(probability(t) * multiple(t) * duration(t) for t in ts)
    @test total_dur ≈ 3 * 5 * 8760

    pers_rp = collect(t for rp in repr_periods(ts) for t in rp)
    @test issetequal(pers, pers_rp)

    pers_rp_os = collect(
        t for rp in repr_periods(ts) for sc in opscenarios(rp) for t in sc
    )
    @test issetequal(pers, pers_rp_os)

    pers_os = collect(
        t for sp in strat_periods(ts) for sc in opscenarios(sp) for t in sc
    )
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

@testitem "Iteration invariants" begin
    using Dates

    function test_invariants(periods)
        pers = collect(t for t in periods)
        @test sum(probability(t) * duration(t) * multiple(t) for t in pers) ≈
              TimeStruct._total_duration(periods)

        pers_rp = collect(t for rp in repr_periods(periods) for t in rp)
        @test issetequal(pers, pers_rp)

        pers_sc = collect(t for sc in opscenarios(periods) for t in sc)
        @test issetequal(pers, pers_sc)

        pers_sp = collect(t for sp in strat_periods(periods) for t in sp)
        @test issetequal(pers, pers_sp)

        pers_rp_sc = collect(
            t for rp in repr_periods(periods) for sc in opscenarios(rp) for
            t in sc
        )
        @test issetequal(pers, pers_rp_sc)

        pers_sp_rp = collect(
            t for sp in strat_periods(periods) for rp in repr_periods(sp)
            for t in rp
        )
        @test issetequal(pers, pers_sp_rp)

        pers_sp_sc = collect(
            t for sp in strat_periods(periods) for sc in opscenarios(sp) for
            t in sc
        )
        @test issetequal(pers, pers_sp_sc)

        pers_sp_rp_sc = collect(
            t for sp in strat_periods(periods) for rp in repr_periods(sp)
            for sc in opscenarios(rp) for t in sc
        )
        @test issetequal(pers, pers_sp_rp_sc)

        repr_pers = collect(rp for rp in repr_periods(periods))
        repr_pers_sp = collect(
            rp for sp in strat_periods(periods) for rp in repr_periods(sp)
        )
        @test issetequal(repr_pers, repr_pers_sp)

        opscens = collect(sc for sc in opscenarios(periods))
        opscens_sp = collect(
            sc for sp in strat_periods(periods) for sc in opscenarios(sp)
        )
        @test issetequal(opscens, opscens_sp)
        opscens_rp_sp = collect(
            sc for sp in strat_periods(periods) for rp in repr_periods(sp)
            for sc in opscenarios(rp)
        )
        @test issetequal(opscens, opscens_rp_sp)
    end

    test_invariants(SimpleTimes(10, 1))
    test_invariants(
        CalendarTimes(Dates.DateTime(2023, 1, 1), 12, Dates.Month(1)),
    )
    test_invariants(OperationalScenarios(3, SimpleTimes(10, 1)))
    test_invariants(
        RepresentativePeriods(
            2,
            10,
            [0.2, 0.8],
            [SimpleTimes(10, 1), SimpleTimes(5, 1)],
        ),
    )
    opscen = OperationalScenarios(
        2,
        [SimpleTimes(10, 1), SimpleTimes(5, 3)],
        [0.4, 0.6],
    )
    repr_op = RepresentativePeriods(2, 10, [0.2, 0.8], [opscen, opscen])
    test_invariants(repr_op)

    test_invariants(TwoLevel(5, 10, SimpleTimes(10, 1)))
    test_invariants(TwoLevel(5, 30, opscen))

    repr = RepresentativePeriods(
        2,
        20,
        [0.2, 0.8],
        [SimpleTimes(5, 1), SimpleTimes(5, 1)],
    )
    two_level = TwoLevel(100, [repr, repr, repr]; op_per_strat = 1.0)
    test_invariants(two_level)

    repr = RepresentativePeriods(2, 20, [0.2, 0.8], [opscen, opscen])
    two_level = TwoLevel(100, [repr, repr]; op_per_strat = 1.0)
    test_invariants(two_level)
end

@testitem "Last for time structures" begin
    using Dates

    function test_last(periods)
        @test last(periods) == last(collect(periods))

        @test last(strategic_periods(periods)) ==
              last(collect(strategic_periods(periods)))
        @test last(repr_periods(periods)) ==
              last(collect(repr_periods(periods)))

        for sp in strategic_periods(periods)
            @test last(sp) == last(collect(sp))
            @test last(repr_periods(sp)) == last(collect(repr_periods(sp)))
            for rp in repr_periods(sp)
                @test last(rp) == last(collect(rp))
                for scen in opscenarios(rp)
                    @test last(scen) == last(collect(scen))
                end
            end
        end

        for rp in repr_periods(periods)
            @test last(rp) == last(collect(rp))
            for scen in opscenarios(rp)
                @test last(scen) == last(collect(scen))
            end
        end

        for scen in opscenarios(periods)
            @test last(scen) == last(collect(scen))
        end
    end

    periods = SimpleTimes(24, 1)
    test_last(periods)

    periods = CalendarTimes(Dates.DateTime(2023, 1, 1), 12, Dates.Month(1))
    test_last(periods)

    periods = RepresentativePeriods(
        2,
        20,
        [0.2, 0.8],
        [SimpleTimes(5, 1), SimpleTimes(5, 1)],
    )
    test_last(periods)

    opscen = OperationalScenarios(
        2,
        [SimpleTimes(10, 1), SimpleTimes(5, 3)],
        [0.4, 0.6],
    )
    test_last(opscen)

    periods = TwoLevel(2, 1, SimpleTimes(4, 1))
    test_last(periods)

    periods = TwoLevel(2, 1, opscen)
    test_last(periods)

    rep = RepresentativePeriods(2, 20, [0.2, 0.8], [opscen, opscen])
    test_last(rep)

    periods = TwoLevel(2, 1, rep)
    test_last(periods)
end

@testitem "Duration invariants" begin

    #=
    day = SimpleTimes(24,1)
    @test sum(duration(sp) for sp in strat_periods(day)) == TimeStruct._total_duration(day)
    @test sum(duration(rp) for rp in repr_periods(day)) == TimeStruct._total_duration(day)
    @test sum(duration(sc) for sc in opscenarios(day)) == TimeStruct._total_duration(day)
    @test sum(duration(rp) for sp in strat_periods(day) for rp in repr_periods(sp)) == TimeStruct._total_duration(day)

    periods = TwoLevel(10, 240, day)
    @test sum(duration(sp) for sp in strat_periods(periods)) == TimeStruct._total_duration(periods)
    @test sum(duration(rp) for sp in strat_periods(periods) for rp in repr_periods(sp)) == TimeStruct._total_duration(periods)
    =#

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

    indices = [day...][[1, 6]]
    @test fp[indices...] == [12, 12]
    @test fp[indices] == [12, 12]

    @test_throws ErrorException fp["dummy"]

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

    @test op[indices...] == [2, 1]
    @test op[indices] == [2, 1]

    @test_throws ErrorException op["dummy"]

    @test sum(fp[t_inv] == 12 for t_inv in strat_periods(day)) == 1

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

    indices = [ts...][[10, 20, 30]]
    @test sp2[indices...] == [2, 12, 12]
    @test sp2[indices] == [2, 12, 12]

    @test_throws ErrorException sp1["dummy"]

    tsc = TwoLevel(3, 168, OperationalScenarios(3, SimpleTimes(7, 24)))
    @test sum(fp[t] for t in tsc) == 12.0 * length(tsc)
    scp = ScenarioProfile([op, 2 * op, 3 * op])
    @test sum(scp[t] for t in tsc) == 3 * (11 + 2 * 11 + 3 * 11)

    @test_throws ErrorException scp["dummy"]

    scp2 = ScenarioProfile([
        OperationalProfile([1, 1, 2]),
        FixedProfile(3),
        OperationalProfile([4, 5]),
    ])
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
    ops3 = [t for sp in strategic_periods(regtree) for t in sp]
    @test ops == ops3

    op = ops[31]
    @test TimeStruct._opscen(op) == 1
    @test TimeStruct._strat_per(op) == 3
    @test TimeStruct._branch(op) == 4
    @test TimeStruct._oper(op) == 1
    @test duration(op) == 1
    @test probability(op) == 1 / 6
    @test op isa eltype(typeof(regtree))

    nodes = strat_nodes(regtree)
    for sp in 1:3
        @test sum(TimeStruct.probability_branch(n) for n in nodes if n.sp == sp) ≈ 1.0
    end
    node = nodes[2]
    @test length(node) == 5
    @test first(node) isa eltype(typeof(node))

    leaves = TimeStruct.leaves(regtree)
    @test length(leaves) == TimeStruct.nleaves(regtree)

    scens = collect(TimeStruct.strategic_scenarios(regtree))
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

@testitem "Profiles constructors" begin
    # Checking the input type
    @test_throws MethodError FixedProfile("wrong_input")
    @test_throws MethodError OperationalProfile("wrong_input")
    @test_throws MethodError ScenarioProfile("wrong_input")
    @test_throws MethodError RepresentativeProfile("wrong_input")
    @test_throws MethodError StrategicProfile("wrong_input")
    @test_throws MethodError StrategicProfile("StrategicStochasticProfile")
end

@testitem "Profiles and strategic periods" begin
    profile = StrategicProfile([1, 2, 3])

    simple = SimpleTimes(10, 1)
    sp = first(strat_periods(simple))

    @test profile[sp] == 1

    ts = TwoLevel(3, 5, SimpleTimes(5, 1))
    vals = collect(profile[sp] for sp in strat_periods(ts))
    @test vals == [1, 2, 3]

    repr = RepresentativePeriods(
        2,
        5,
        [0.6, 0.4],
        [SimpleTimes(5, 1), SimpleTimes(5, 1)],
    )
    ts = TwoLevel(3, 5, repr)

    vals = collect(profile[sp] for sp in strat_periods(ts))
    @test vals == [1, 2, 3]
end

@testitem "Profiles and representative periods" begin
    profile = RepresentativeProfile([
        FixedProfile(1),
        FixedProfile(2),
        FixedProfile(3),
    ])

    simple = SimpleTimes(10, 1)
    rp = first(repr_periods(simple))

    @test profile[rp] == 1

    ts = TwoLevel(3, 5, SimpleTimes(5, 1))
    vals = collect(profile[rp] for rp in repr_periods(ts))
    @test vals == [1, 1, 1]

    repr = RepresentativePeriods(
        2,
        5,
        [0.6, 0.4],
        [SimpleTimes(5, 1), SimpleTimes(5, 1)],
    )
    ts = TwoLevel(3, 5, repr)

    vals = collect(profile[rp] for rp in repr_periods(ts))
    @test vals == [1, 2, 1, 2, 1, 2]

    vals2 = profile[repr_periods(ts)]
    @test vals2 == vals

    sprofile = StrategicProfile([profile, 2 * profile, 3 * profile])
    vals = collect(sprofile[rp] for rp in repr_periods(ts))
    @test vals == [1, 2, 2, 4, 3, 6]
end

@testitem "Profiles and operational scenarios" begin
    profile =
        ScenarioProfile([FixedProfile(1), FixedProfile(2), FixedProfile(3)])

    simple = SimpleTimes(10, 1)
    sc = first(opscenarios(simple))

    @test profile[sc] == 1

    ts = TwoLevel(3, 5, SimpleTimes(5, 1))
    vals = collect(profile[sc] for sc in opscenarios(ts))
    @test vals == [1, 1, 1]

    oscen = OperationalScenarios([SimpleTimes(5, 1), SimpleTimes(5, 1)])
    repr = RepresentativePeriods(2, 5, [0.6, 0.4], [oscen, oscen])
    ts = TwoLevel(3, 5, repr)

    vals = collect(profile[sc] for sc in opscenarios(ts))
    @test vals == [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2]

    rprofile = RepresentativeProfile([profile, profile + 2])
    sprofile = StrategicProfile([rprofile, 2 * rprofile, 3 * rprofile])
    vals = collect(sprofile[sc] for sc in opscenarios(ts))
    @test vals == [1, 2, 3, 4, 2, 4, 6, 8, 3, 6, 9, 12]
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

@testitem "Strategic scenarios with operational scenarios" begin
    regtree = TimeStruct.regular_tree(
        5,
        [3, 2],
        OperationalScenarios(3, SimpleTimes(5, 1)),
    )

    @test length(strategic_scenarios(regtree)) == 6

    for sc in strategic_scenarios(regtree)
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

    scens = TimeStruct.strategic_scenarios(two_level)
    @test length(scens) == 1
    sps = collect(sp for sc in TimeStruct.strategic_scenarios(two_level) for sp in strat_periods(sc))
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

    periods = SimpleTimes(10, 1)

    per_next = collect(collect(ts) for ts in chunk(periods, 5))
    @test length(per_next[1]) == 5
    @test length(per_next[7]) == 4
    @test length(per_next[10]) == 1
    @test per_next[1] == collect(Iterators.take(periods, 5))

    per_prev =
        collect(collect(ts) for ts in chunk(Iterators.reverse(periods), 5))
    @test length(per_prev[1]) == 5
    @test length(per_next[7]) == 4
    @test length(per_next[10]) == 1
    @test per_prev[10] == [first(periods)]

    per_cyclic = collect(collect(ts) for ts in chunk(periods, 5; cyclic = true))
    for pc in per_cyclic
        @test length(pc) == 5
    end

    periods = SimpleTimes([1, 1, 2, 2, 3, 1, 3])
    pers = [t for t in TimeStruct.take_duration(periods, 5)]
    @test sum(duration(t) for t in pers) >= 5

    sdur = collect(collect(ts) for ts in chunk_duration(periods, 5))
    for s in sdur
        @test (sum(duration(t) for t in s) >= 5) || (last(periods) in s)
    end
end

@testitem "Indexing of operational structures" begin
    using Dates

    periods = SimpleTimes(10, 1)

    @test periods[1] == first(periods)
    @test periods[10] == last(periods)

    year = CalendarTimes(DateTime(2024, 1, 1), 12, Month(1))
    @test year[5] == collect(year)[5]

    two_level = TwoLevel(5, 100, SimpleTimes(5, 1))

    scen = first(opscenarios(two_level))
    @test scen[1] == first(two_level)
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

    @test sum(
        objective_weight(sp, periods, 0.04; timeunit_to_year = 1 / 8760) for
        sp in strat_periods(periods)
    ) ≈ 8.435 atol = 1e-3

    uniform_day = SimpleTimes(24, 1u"hr")
    periods_unit = TwoLevel(10, 365.125u"d", uniform_day)

    @test sum(
        objective_weight(sp, disc) for sp in strat_periods(periods_unit)
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
Aqua.test_all(TimeStruct; ambiguities = false)
