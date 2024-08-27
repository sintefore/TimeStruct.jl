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

multiple_strat(sp::StratNode, t) = multiple(t) / duration_strat(sp)

abstract type StrategicTreeIndexable end

struct HasStratTreeIndex <: StrategicTreeIndexable end
struct NoStratTreeIndex <: StrategicTreeIndexable end

StrategicTreeIndexable(::Type) = NoStratTreeIndex()
StrategicTreeIndexable(::Type{<:AbstractTreeNode}) = HasStratTreeIndex()
StrategicTreeIndexable(::Type{<:TimePeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:AbstractTreeNode}) = HasStratIndex()
