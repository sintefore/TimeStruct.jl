module TimeStruct

import Dates
import TimeZones

import .Base: first, last, isempty, length, size, eltype, IteratorSize, IteratorEltype

include("structures.jl")
include("simple.jl")
include("calendar.jl")
include("representative/core_types.jl")
include("op_scenarios/core_types.jl")
include("strategic/core_types.jl")
include("strategic/strat_periods.jl")
include("strat_scenarios/tree_periods.jl")
include("strat_scenarios/core_types.jl")
include("representative/rep_periods.jl")
include("representative/strat_periods.jl")
include("representative/tree_periods.jl")
include("op_scenarios/opscenarios.jl")
include("op_scenarios/rep_periods.jl")
include("op_scenarios/strat_periods.jl")
include("op_scenarios/tree_periods.jl")

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

export TreeNode

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
export withprev, withnext, chunk, chunk_duration
export isfirst, duration, duration_strat, multiple
export probability, probability_branch, probability_scen
export multiple_strat
export mult_scen, mult_repr, mult_strat
export start_time, end_time, remaining
export start_oper_time, end_oper_time
export n_strat_per, n_children, n_leaves, n_branches

export Discounter
export discount
export objective_weight

end # module
