module TimeStruct

import Dates
import TimeZones

import .Base:
    first, last, isempty, length, size, eltype, IteratorSize, IteratorEltype

include("structures.jl")
include("simple.jl")
include("calendar.jl")
include(joinpath("representative", "core_types.jl"))
include(joinpath("op_scenarios", "core_types.jl"))
include(joinpath("strategic", "core_types.jl"))
include(joinpath("strategic", "strat_periods.jl"))
include(joinpath("representative", "rep_periods.jl"))
include(joinpath("representative", "strat_periods.jl"))
include(joinpath("op_scenarios", "opscenarios.jl"))
include(joinpath("op_scenarios", "rep_periods.jl"))
include(joinpath("op_scenarios", "strat_periods.jl"))

include(joinpath("strat_scenarios", "tree_periods.jl"))
include(joinpath("strat_scenarios", "core_types.jl"))

include("utils.jl")
include("discount.jl")
include("profiles.jl")

export TimeStructure
export SimpleTimes
export CalendarTimes
export OperationalScenarios
export RepresentativePeriods
export TwoLevel
export TwoLevelTree

export TimeProfile
export FixedProfile
export OperationalProfile
export ScenarioProfile
export StrategicProfile
export StrategicStochasticProfile
export RepresentativeProfile

export opscenarios
export repr_periods
export strat_periods, strategic_periods
export regular_tree, strat_nodes, strategic_scenarios
export withprev, chunk, chunk_duration
export isfirst, duration, duration_strat, multiple, probability
export multiple_strat
export start_time, end_time, remaining
export start_oper_time, end_oper_time

export Discounter
export discount
export objective_weight

end # module
