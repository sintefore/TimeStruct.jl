module TimeStructures

include("structures.jl")
include("stochastic.jl")
include("twolevel.jl")
include("profiles.jl")
include("utils.jl")
include("discount.jl")

export OperationalPeriod
export StrategicPeriod
export SimplePeriod
export SimpleTimes
export TwoLevel


export TimeProfile, TimeStructure
export FixedProfile
export OperationalProfile
export StrategicProfile
export DynamicProfile

export ScenarioPeriod
export OperationalScenarios
export OperationalScenario
export ScenarioProfile
export scenarios
export probability

export strat_periods, strat_periods_index, strat_per

export withprev

export isfirst, duration, multiple

export Discounter
export discount
export objective_weight

end # module
