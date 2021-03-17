module TimeStructures

include("timestructures.jl")
include("profiles.jl")

export OperationalPeriod
export StrategicPeriod
export UniformTimes
export UniformTwoLevel

export DynamicProfile
export FixedProfile
export StrategicFixedProfile

export next
export previous
export strategic_periods

end # module
