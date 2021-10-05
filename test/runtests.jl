using Test
using TimeStructures
const TS = TimeStructures

day = SimpleTimes(24,1)             # One day with hourly resolution   
    
@testset "Simple Times" begin
    @test first(day) == SimplePeriod(1,1)
    @test length(day) == 24
    @test isfirst(SimplePeriod(1,1)) 
    @test first(day) < SimplePeriod(3,1)

    tops = collect(t for t in day)
    @test tops[2] == SimplePeriod(2,1)
end

@testset "Two level structure" begin
    uniform_week = TwoLevel(7, 24, day)  # 7 strategic periods, hourly resolution each day
    
    @test typeof(uniform_week) == TwoLevel
    @test length(uniform_week) == 168

    # One year with monthly strategic periods and one day of operations for each month
    monthly_hours = 24 .* [31,28,31,30,31,30,31,31,30,31,30,31]
    uniform_year = TwoLevel(12, monthly_hours, day)

    @test length(uniform_year) == 12 * 24
    @test sum(sp.duration for sp in strat_periods(uniform_year)) == 8760
    @test multiple(first(uniform_year), uniform_year) == 31

end

@testset "Operational scenarios" begin
    week = SimpleTimes(168,1)
    # 3 operational scenarios, two single day and one for a week
    opscen = ScenarioOperational(3, [day, day, week], [0.1, 0.2, 0.7])
    @test first(opscen) == ScenarioPeriod(1,1,1.0)

    @test length(opscen) == 216

    seasonal_year = TwoLevel(4, 24 .* [91, 91, 91, 92], opscen)

    @test first(seasonal_year) == OperationalPeriod(1, 1, 1, 1.0)
end


@testset "Time Profiles" begin

    
    fp = FixedProfile(12.0)
    @test fp[first(day)] == 12.0

    sfp = StrategicProfile([i/100 for i ∈ 1:365])
    @test sfp[OperationalPeriod(122,1)] == 1.22
    @test sfp[StrategicPeriod(122, 1, SimpleTimes(24,1))] == 1.22

    dp = DynamicProfile([OperationalProfile([i/100 + j for j ∈ 1:24]) for i ∈ 1:365])
    @test dp[OperationalPeriod(365,24)] == 27.65

end

@testset "Iteration Utils" begin
    uniform_day = SimpleTimes(24,1)    
    uniform_week = TwoLevel(7,24,uniform_day)

    @test first(withprev(uniform_day))[1] === nothing
    @test collect(withprev(uniform_week))[25] == (nothing, OperationalPeriod(2,1,1.0))

end

@testset "Discount" begin
    uniform_years = SimpleTimes(10,1)  # 10 years with duration of 1 year
    disc = Discounter(0.04, 1, uniform_years)

    δ = 1 / 1.04
    for (i,t) in enumerate(uniform_years)
        @test discount(disc, t) == (i-1)^δ
    end
end