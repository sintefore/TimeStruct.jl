"""
    abstract type AbstractStrategicScenario{T} <: TimeStructurePeriod{T}

Abstract type used for time structures that represent a strategic scenario.
These periods are obtained when iterating through the strategic scenarios of a time
structure declared by the function [`strategic_scenarios`](@ref).
"""
abstract type AbstractStrategicScenario{T} <: TimeStructurePeriod{T} end

"""
    abstract type AbstractStratScens{S,T} <: TimeStructInnerIter

Abstract type used for time structures that represent a collection of strategic scenarios,
obtained through calling the function [`strategic_scenarios`](@ref).
"""
abstract type AbstractStratScens{T} <: TimeStructInnerIter{T} end

"""
    struct StrategicScenario{S,T,OP<:AbstractTreeNode{S,T}} <: AbstractStrategicScenario{T}

Description of an individual strategic scenario. It includes all strategic nodes
corresponding to a scenario, including the probability. It can be utilized within a
decomposition algorithm.
"""
struct StrategicScenario{S,T,N,OP<:AbstractTreeNode{S,T}} <: AbstractStrategicScenario{T}
    scen::Int64
    probability::Float64
    nodes::NTuple{N,<:OP}
end

Base.show(io::IO, scen::StrategicScenario) = print(io, "scen$(scen.scen)")

# Add basic functions of iterators
Base.length(scen::StrategicScenario) = length(scen.nodes)
Base.last(scen::StrategicScenario) = last(scen.nodes)
Base.eltype(_::Type{StrategicScenario{S,T,N,OP}}) where {S,T,N,OP} = OP
function Base.iterate(scs::StrategicScenario, state = nothing)
    next = isnothing(state) ? iterate(scs.nodes) : iterate(scs.nodes, state)
    isnothing(next) && return nothing
    return next[1], next[2]
end

"""
    struct StratScens{S,T,OP<:AbstractTreeNode{S,T}} <: AbstractStratScens{T}

Type for iteration through the individual strategic scenarios represented as
[`StrategicScenario`](@ref).
"""
struct StratScens{S,T,OP<:AbstractTreeNode{S,T}} <: AbstractStratScens{T}
    ts::TwoLevelTree{S,T,OP}
end

"""
    strategic_scenarios(ts::TwoLevel)
    strategic_scenarios(ts::TwoLevelTree)

This function returns a type for iterating through the individual strategic scenarios of a
`TwoLevelTree`. The type of the iterator is dependent on the type of the
input `TimeStructure`.

When the `TimeStructure` is a [`TwoLevel`](@ref), `strategic_scenarios` returns a Vector with
the `TwoLevel` as a single entry.
"""
strategic_scenarios(ts::TwoLevel) = [ts]

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strategic_scenarios` returns the
iterator `StratScens`.
"""
strategic_scenarios(ts::TwoLevelTree) = StratScens(ts)
# Allow a TwoLevel structure to be used as a tree with one scenario
# TODO: Should be replaced with a single wrapper as it is the case for the other scenarios

# Provide a constructor to simplify the design
function StrategicScenario(
    scs::StratScens{S,T,OP},
    scen::Int,
) where {S,T,OP<:TimeStructure{T}}
    node = get_leaf(scs.ts, scen)
    prob = probability_branch(node)
    n_strat_per = _strat_per(node)
    nodes = Vector{OP}(undef, n_strat_per)
    for sp in n_strat_per:-1:1
        nodes[sp] = node
        node = _parent(node)
    end

    return StrategicScenario(scen, prob, Tuple(nodes))
end

# Add basic functions of iterators
Base.length(scens::StratScens) = n_leaves(scens.ts)
function Base.eltype(_::StratScens{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StrategicScenario
end
function Base.iterate(scs::StratScens, state = nothing)
    scen = isnothing(state) ? 1 : state + 1
    scen > n_leaves(scs.ts) && return nothing

    return StrategicScenario(scs, scen), scen
end
function Base.getindex(scs::StratScens, index::Int)
    return StrategicScenario(scs, index)
end
function Base.eachindex(scs::StratScens)
    return Base.OneTo(n_leaves(scs.ts))
end
function Base.last(scs::StratScens)
    return StrategicScenario(scs, length(scs))
end
