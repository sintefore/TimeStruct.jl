"""
    AbstractTreeNode{T} <: TimeStructure{T}

Abstract base type for all tree nodes within a [`TwoLevelTree`] type
"""
abstract type AbstractTreeNode{T} <: TimeStructure{T} end

struct StratNode{S, T, OP<:TimeStructure{T}} <: AbstractTreeNode{T}
    sp::Int
    branch::Int
    duration::S
    prob_branch::Float64
    mult_sp::Float64
    parent::Any
    operational::OP
end

Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
_branch(n::StratNode) = n.branch
_strat_per(n::StratNode) = n.sp
probability_branch(n::StratNode) = n.prob_branch
duration_strat(n::StratNode) = n.duration
multiple_strat(sp::StratNode, t) = multiple(t) / duration_strat(sp)

isfirst(n::StratNode) = n.sp == 1

# Iterate through time periods of a strategic node
Base.length(n::StratNode) = length(n.operational)
Base.eltype(::Type{StratNode{T}}) where {T} = TreePeriod
function Base.iterate(itr::StratNode, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]

    mult = itr.mult_sp * multiple(per)
    return TreePeriod(itr.sp, itr.branch, probability_branch(itr), mult, per),
    next[2]
end

abstract type StrategicTreeIndexable end

struct HasStratTreeIndex <: StrategicTreeIndexable end
struct NoStratTreeIndex <: StrategicTreeIndexable end

StrategicTreeIndexable(::Type) = NoStratTreeIndex()
StrategicTreeIndexable(::Type{<:AbstractTreeNode}) = HasStratTreeIndex()
StrategicTreeIndexable(::Type{<:TimePeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:AbstractTreeNode}) = HasStratIndex()


"""
    struct StratNodeOperationalScenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a strategic node supporting
iteration over its time periods.
"""
struct StratNodeOperationalScenario{T} <: AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::TimeStructure{T}
end

function Base.show(io::IO, os::StratNodeOperationalScenario)
    return print(io, "sp$(os.sp)-br$(os.branch)-sc$(os.scen)")
end

probability(os::StratNodeOperationalScenario) = os.prob_branch * prob_scen
mult_scen(os::StratNodeOperationalScenario) = os.mult_scen
_opscen(os::StratNodeOperationalScenario) = os.scen
_branch(os::StratNodeOperationalScenario) = os.branch
_strat_per(os::StratNodeOperationalScenario) = os.sp

StrategicTreeIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratIndex()

Base.length(snops::StratNodeOperationalScenario) = length(snops.operational)
Base.eltype(_::StratNodeOperationalScenario) = TreePeriod

function Base.last(os::StratNodeOperationalScenario)
    per = last(os.operational)
    return OperationalPeriod(os.sp, per, os.mult_sp * multiple(per))
end

function Base.getindex(os::StratNodeOperationalScenario, index)
    per = os.operational[index]
    mult = os.mult_sp * multiple(per)
    return TreePeriod(os.sp, os.branch, probability_branch(os), mult, per)
end

function Base.eachindex(os::StratNodeOperationalScenario)
    return eachindex(os.operational)
end

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(os::StratNodeOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(os.sp, os.branch, os.prob_branch, os.mult_sp * multiple(next[1]), next[1]),
    next[2]
end


# Iteration through scenarios
"""
    struct StratNodeOpScens

Type for iterating through the individual operational scenarios of a [`StratNode`](@ref).
It is automatically created through the function [`opscenarios`](@ref).
"""
struct StratNodeOpScens
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    opscens::Any
end

function StratNodeOpScens(n::StratNode{S,T,OP}, opscens) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(_strat_per(n), _branch(n), n.mult_sp, probability_branch(n), opscens)
end

Base.length(ops::StratNodeOpScens) = length(ops.opscens)
Base.eltype(_::StratNodeOpScens) = StratNodeOperationalScenario

"""
    opscenarios(sp::StratNode{S,T,OP})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function opscenarios(sper::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(sper, opscenarios(sper.operational))
end

function Base.iterate(ops::StratNodeOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.opscens) :
        iterate(ops.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeOperationalScenario(
        ops.sp,
        ops.branch,
        scen,
        ops.mult_sp,
        mult_scen(next[1]),
        ops.prob_branch,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end
