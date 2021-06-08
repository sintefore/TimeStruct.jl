module TimeStructures

include("structures.jl")
include("profiles.jl")
include("utils.jl")

export OperationalPeriod
export StrategicPeriod
export UniformTimes
export DynamicTimes
export UniformTwoLevel

export TimeProfile
export DynamicProfile
export FixedProfile
export StrategicFixedProfile

export next, previous
export strategic_periods
export first_operational, last_operational
export withprev

end # module
