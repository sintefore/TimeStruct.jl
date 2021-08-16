using Test
using TimeStructures
const TS = TimeStructures

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

@testset "Two level time structures" begin
    spring = UniformTimes(1,72,2)
    summer = UniformTimes(1,144,2)
    autumn = UniformTimes(1,72,2)
    winter = UniformTimes(1,36,2)
    varying_year = [spring, summer, autumn, winter]
    varying_two_year = [spring, summer, autumn, winter, spring, summer, autumn, winter]

    uniform_year = UniformTimes(1,324,2)

    dynamic_strategic = DynamicStrategicLevel(1,2,[1,4],uniform_year)
    dynamic_two_level = DynamicTwoLevel(1,8,[0.25, 0.25, 0.25, 0.25, 1, 1, 1, 1],varying_two_year)

    @test length(dynamic_strategic) == length(dynamic_two_level)

    T = DynamicOperationalLevel(1, 2, 1, [UniformTimes(1, 10, 10), UniformTimes(1, 10, 5)])
    T_inv = strategic_periods(T)
    T_ops = [collect(t_inv) for t_inv ∈ T_inv]

    @test T_ops[1][10].duration == 10
    @test previous(T_ops[1][2],T).duration == 10
    @test previous(T_ops[1][2]).duration == 1
    @test previous(T_ops[2][2],T).duration == 5

    T_ops = [collect(t) for t ∈ strategic_periods(T)]
    @test T_ops[1][10].duration == 10
    @test T_ops[2][10].duration == 5

end

@testset "Dynamic Times" begin
    dynamic_day = DynamicTimes(1,6,[12,4,1,1,2,4])
    @test length(dynamic_day) == 6
    @test sum([t.duration for t in dynamic_day]) == 24
    @test collect(dynamic_day)[2] == TS.DynamicPeriod(2,4)
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

@testset "Iteration Utils" begin
    uniform_day = UniformTimes(1,24,1)    
    uniform_week = UniformTwoLevel(1,7,1,uniform_day)

    @test first(withprev(uniform_day))[1] === nothing
    @test collect(withprev(uniform_week))[25] == (nothing, TS.OperationalPeriod(2,1))

end