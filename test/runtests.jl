using Test
using TimeStructures

@testset "Uniform Times" begin
    uniform_day = UniformTimes(1,24,1)    
    uniform_year = UniformTwoLevel(1,365,1,uniform_day)
    
    @test typeof(uniform_year) == UniformTwoLevel
    @test length(uniform_year) == 8760
    
    uniform_two_years = UniformTwoLevel(1,365,2,uniform_day)
    @test length(uniform_year) == 8760

    first_period = OperationalPeriod(1, 1)
    @test sum([t.idx for t ∈ UniformTimes(1,10,1)]) == sum(1:10)
    @test sum([t.duration for t ∈ UniformTimes(1,10,1)]) == 10
    
    @test first(strategic_periods(uniform_year)) == StrategicPeriod(1, 365, 24, 1, UniformTimes(1, 24, 1))
    @test length(first(strategic_periods(uniform_year))) == 24
    @test iterate(uniform_two_years, OperationalPeriod(1,24))[2] == OperationalPeriod(2,1)
    @test iterate(first(strategic_periods(uniform_year)))[2] == OperationalPeriod(1, 2, 1)
    @test previous(next(first(strategic_periods(uniform_year)))) ==  StrategicPeriod(1, 365, 24, 1, UniformTimes(1, 24, 1))

    @test length(first(uniform_year, 10)) == 10
    @test [t.idx for t ∈ first(uniform_year, 2)] == [(1, 1), (1, 2)]
    
    @test first_operational(first(strategic_periods(uniform_year))) == OperationalPeriod(1, 1)
    @test last_operational(first(strategic_periods(uniform_year))) == OperationalPeriod(1, 24)
    @test previous(OperationalPeriod(1, 2)) == OperationalPeriod(1, 1)
    @test previous(OperationalPeriod(1, 1)) === nothing

    T = UniformTwoLevel(1, 2, 1, UniformTimes(1, 24, 1))
    T_inv = strategic_periods(T)
    T_ops = [collect(t_inv) for t_inv ∈ T_inv]
    @test T_ops[1][24] == OperationalPeriod(1,24)
    @test T_ops[2][1] == OperationalPeriod(2,1)
end

@testset "Time Profiles" begin
    
    fp = FixedProfile(12.0)
    @test fp[1] == 12.0

    sfp = StrategicFixedProfile([i/100 for i ∈ 1:365])
    @test sfp[OperationalPeriod(122,1)] == 1.22
    @test sfp[StrategicPeriod(122, 1, 1, 1, UniformTimes(1,24,1))] == 1.22

    dp = DynamicProfile([i/100 + j for i ∈ 1:365, j ∈ 1:24])
    @test dp[OperationalPeriod(365,24)] == 27.65

end