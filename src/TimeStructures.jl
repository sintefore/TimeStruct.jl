module TimeStructures

include("structures.jl")
include("profiles.jl")
include("utils.jl")

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

export next, previous
export strategic_periods
export startyear, endyear, duration_years
export first_operational, last_operational
export withprev

end # module
