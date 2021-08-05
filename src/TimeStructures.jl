module TimeStructures

include("structures.jl")
include("profiles.jl")
include("utils.jl")

export OperationalPeriod
export StrategicPeriod
export UniformTimes
export DynamicTimes
export UniformTwoLevel
export DynamicOperationalLevel
export DynamicStrategicLevel
export DynamicTwoLevel

export TimeProfile, TimeStructure
export DynamicProfile
export FixedProfile
export OperationalFixedProfile
export StrategicFixedProfile

export next, previous
export strategic_periods
export startyear, endyear, duration_years
export first_operational, last_operational
export withprev

end # module
