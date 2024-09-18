"""
    abstract type AbstractTreeNode{S,T} <: AbstractStrategicPeriod{S,T}

Abstract base type for all tree nodes within a [`TwoLevelTree`](@ref) type.
"""
abstract type AbstractTreeNode{S,T} <: AbstractStrategicPeriod{S,T} end

"""
    abstract type AbstractTreeStructure{T} <: TimeStructOuterIter{T}

Abstract base type for all tree timestructures within a [`TwoLevelTree`](@ref) type.
"""
abstract type AbstractTreeStructure{T} <: TimeStructOuterIter{T} end

Base.length(ats::AbstractTreeStructure) = length(_oper_struct(ats))
function Base.iterate(ats::AbstractTreeStructure, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(_oper_struct(ats)) :
        iterate(_oper_struct(ats), state[1])
    isnothing(next) && return nothing

    return strat_node_period(ats, next[1], state[2]), (next[2], state[2] + 1)
end

abstract type StrategicTreeIndexable end
struct HasStratTreeIndex <: StrategicTreeIndexable end
struct NoStratTreeIndex <: StrategicTreeIndexable end

StrategicTreeIndexable(::Type) = NoStratTreeIndex()
StrategicTreeIndexable(::Type{<:AbstractTreeNode}) = HasStratTreeIndex()
StrategicTreeIndexable(::Type{<:TimePeriod}) = HasStratTreeIndex()

"""
    struct StratNode{S, T, OP<:TimeStructure{T}} <: AbstractTreeNode{S,T}

A structure representing a single strategic node of a [`TwoLevelTree`](@ref). It is created
through iterating through [`StratTreeNodes`](@ref).

It is equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwoLevelTree`](@ref).
"""
struct StratNode{S,T,OP<:TimeStructure{T}} <: AbstractTreeNode{S,T}
    sp::Int
    branch::Int
    duration::S
    prob_branch::Float64
    mult_sp::Float64
    parent::Any
    operational::OP
end

_strat_per(n::StratNode) = n.sp
_branch(n::StratNode) = n.branch

probability_branch(n::StratNode) = n.prob_branch
mult_strat(n::StratNode) = n.mult_sp
duration_strat(n::StratNode) = n.duration
multiple_strat(sp::StratNode, t) = multiple(t) / duration_strat(sp)

_parent(n::StratNode) = n.parent

isfirst(n::StratNode) = n.sp == 1

# Adding methods to existing Julia functions
Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
Base.length(n::StratNode) = length(n.operational)
Base.eltype(::Type{StratNode{S,T,OP}}) where {S,T,OP} = TreePeriod{eltype(OP)}
function Base.iterate(n::StratNode, state = nothing)
    next = isnothing(state) ? iterate(n.operational) : iterate(n.operational, state)
    next === nothing && return nothing

    return TreePeriod(n, next[1]), next[2]
end
