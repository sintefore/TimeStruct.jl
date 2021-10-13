module TimeStructures

include("structures.jl")
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
export ScenarioOperational
export ScenarioProfile

export strat_periods, strat_per
export strategic_periods
export withprev

export isfirst, duration, multiple

export Discounter
export discount
export objective_weight

end # module
