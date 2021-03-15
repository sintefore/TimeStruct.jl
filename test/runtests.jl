using Test
using TimeStructures

@testset "Uniform Times" begin
    uniform_day = UniformTimes(1,24,1)    
    uniform_year = UniformTwoLevel(1,365,1,uniform_day)
    
    @test typeof(uniform_year) == UniformTwoLevel
    @test length(uniform_year) == 8760
    @test [t.idx for t ∈ first(uniform_year, 2)] == [(1, 1), (1, 2)]
    @test length(first(uniform_year, 10)) == 10
    
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
end