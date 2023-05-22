module TimeStruct

import Unitful

include("structures.jl")
include("simple.jl")
include("stochastic.jl")
include("twolevel.jl")
include("twoleveltree.jl")
include("profiles.jl")
include("utils.jl")
include("discount.jl")

export TimeStructure
export SimpleTimes
export OperationalScenarios
export TwoLevel
export TwoLevelTree

export TimeProfile
export FixedProfile
export OperationalProfile
export ScenarioProfile
export StrategicProfile
export StrategicStochasticProfile
export DynamicStochasticProfile

export opscenarios
export strat_periods, strategic_periods
export regular_tree, strat_nodes, scenarios
export withprev
export isfirst, duration, multiple, probability
export start_time, end_time, remaining
export start_oper_time, end_oper_time

export Discounter
export discount
export objective_weight

export expand_dataframe!

end # module
