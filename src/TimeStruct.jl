module TimeStruct

using Requires

import Unitful

include("structures.jl")
include("simple.jl")
include("stochastic.jl")
include("twolevel.jl")
include("twoleveltree.jl")
include("profiles.jl")
include("utils.jl")
include("discount.jl")


function __init__()
    @require DataFrames="a93c6f00-e57d-5684-b7b6-d8193f3e46c0" include("dataframes.jl")
end



export OperationalPeriod
export StrategicPeriod
export SimplePeriod
export TreeNode
export OperPeriod
export SimpleTimes
export TwoLevel
export TwoLevelTree


export TimeProfile, TimeStructure
export FixedProfile
export OperationalProfile
export StrategicProfile
export DynamicProfile
export StrategicStochasticProfile
export DynamicStochasticProfile

export ScenarioPeriod
export OperationalScenarios
export OperationalScenario
export ScenarioProfile

export opscenarios
export strat_periods, strat_per
export regular_tree, strat_nodes, scenarios
export withprev
export isfirst, duration, multiple, probability

export Discounter
export discount
export objective_weight

end # module
