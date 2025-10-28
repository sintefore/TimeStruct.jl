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
    struct SingleStrategicScenario{T,SC<:TimeStructure{T}} <: AbstractStrategicScenario{T}

A type representing a single strategic scenario supporting iteration over its
time periods. It is created when iterating through [`SingleStrategicScenarioWrapper`](@ref).
"""
struct SingleStrategicScenario{T,SC<:TimeStructure{T}} <: AbstractStrategicScenario{T}
    ts::SC
end

# Add basic functions of iterators
Base.length(sc::SingleStrategicScenario) = length(sc.ts)
Base.eltype(::Type{SingleStrategicScenario{T,SC}}) where {T,SC} = eltype(SC)
function Base.iterate(sc::SingleStrategicScenario, state = nothing)
    next = isnothing(state) ? iterate(sc.ts) : iterate(sc.ts, state)
    return next
end
Base.last(sc::SingleStrategicScenario) = last(sc.ts)

"""
    struct SingleStrategicScenarioWrapper{T,SC<:TimeStructure{T}} <: AbstractStratScens{T}

Type for iterating through the individual strategic periods of a time structure
without [`TwoLevelTree`](@ref). It is automatically created through the function
[`strategic_scenarios`](@ref).
"""
struct SingleStrategicScenarioWrapper{T,SC<:TimeStructure{T}} <: AbstractStratScens{T}
    ts::SC
end

# Add basic functions of iterators
Base.length(scs::SingleStrategicScenarioWrapper) = 1
function Base.iterate(scs::SingleStrategicScenarioWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleStrategicScenario(scs.ts), 1
end
function Base.eltype(::Type{SingleStrategicScenarioWrapper{T,SC}}) where {T,SC}
    return SingleStrategicScenario{T,SC}
end
Base.last(scs::SingleStrategicScenarioWrapper) = SingleStrategicScenario(scs.ts)

"""
When the `TimeStructure` is a [`SingleStrategicScenario`](@ref) or
[`SingleStrategicScenarioWrapper`](@ref), `strat_periods` returns the value of its internal
[`TimeStructure`](@ref).
"""
strat_periods(sc::SingleStrategicScenario) = strat_periods(sc.ts)
strat_periods(sc::SingleStrategicScenarioWrapper) = strat_periods(sc.ts)

"""
    strategic_scenarios(ts::TimeStructure)

This function returns a type for iterating through the individual strategic scenarios of a
`TwoLevelTree`. The type of the iterator is dependent on the type of the
input `TimeStructure`.

When the `TimeStructure` is a `TimeStructure`, `strategic_scenarios` returns a
[`SingleStrategicScenarioWrapper`](@ref). This corresponds to the default behavior.
"""
strategic_scenarios(ts::TimeStructure) = SingleStrategicScenarioWrapper(ts)

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
    op_per_strat::Float64
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
When the `TimeStructure` is a [`StrategicScenario`](@ref), `strat_periods` returns a
[`StratTreeNodes`](@ref) type, which, through iteration, provides [`StratNode`](@ref) types.

These are equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
strat_periods(ts::StrategicScenario) = StratTreeNodes(
    TwoLevelTree(length(ts), first(ts), [n for n in ts.nodes], ts.op_per_strat),
)

"""
    struct StratScens{S,T,OP<:AbstractTreeNode{S,T}} <: AbstractStratScens{T}

Type for iteration through the individual strategic scenarios represented as
[`StrategicScenario`](@ref).
"""
struct StratScens{S,T,OP<:AbstractTreeNode{S,T}} <: AbstractStratScens{T}
    ts::TwoLevelTree{S,T,OP}
end

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strategic_scenarios` returns the
iterator `StratScens`.
"""
strategic_scenarios(ts::TwoLevelTree) = StratScens(ts)

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

    return StrategicScenario(scen, prob, Tuple(nodes), scs.ts.op_per_strat)
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

"""
When the `TimeStructure` is a [`StratScens`](@ref), `strat_periods` returns a
[`StratTreeNodes`](@ref) type, which, through iteration, provides [`StratNode`](@ref) types.

These are equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.

!!! note
    The corresponding `StratTreeNodes` type is equivalent to the created `StratTreeNodes`
    when using `strat_periods` directly on the [`TwoLevelTree`](@ref).
"""
strat_periods(ts::StratScens) = StratTreeNodes(ts.ts)
