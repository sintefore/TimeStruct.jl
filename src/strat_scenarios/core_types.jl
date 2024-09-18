"""
    mutable struct TwoLevelTree{S,T,OP<:AbstractTreeNode{S,T}} <: TimeStructure{T}

Time structure allowing for a tree structure for the strategic level.

For each strategic node in the tree a separate time structure is used for
operational decisions. Iterating the structure will go through all operational periods.
"""
mutable struct TwoLevelTree{S,T,OP<:AbstractTreeNode{S,T}} <: TimeStructure{T}
    len::Int
    root::Any
    nodes::Vector{OP}
    op_per_strat::Float64
end

function TwoLevelTree{S,T,OP}(
    nodes::Vector{OP},
    op_per_strat,
) where {S,T,OP<:AbstractTreeNode{S,T}}
    return TwoLevelTree{S,T,OP}(0, nothing, nodes, op_per_strat)
end

function _multiple_adj(itr::TwoLevelTree, n)
    mult =
        itr.nodes[n].duration * itr.op_per_strat / _total_duration(itr.nodes[n].operational)
    return stripunit(mult)
end
strat_nodes(ts::TwoLevelTree) = ts.nodes

function children(n::StratNode, ts::TwoLevelTree)
    return [c for c in ts.nodes if _parent(c) == n]
end
nchildren(n::StratNode, ts::TwoLevelTree) = count(c -> _parent(c) == n, strat_nodes(ts))

branches(ts::TwoLevelTree, sp::Int) = count(n -> _strat_per(n) == sp, strat_nodes(ts))
leaves(ts::TwoLevelTree) = [n for n in strat_nodes(ts) if nchildren(n, ts) == 0]
nleaves(ts::TwoLevelTree) = count(n -> nchildren(n, ts) == 0, strat_nodes(ts))
getleaf(ts::TwoLevelTree, leaf::Int) = leaves(ts)[leaf]

function Base.length(itr::TwoLevelTree)
    return sum(length(n.operational) for n in itr.nodes)
end
Base.eltype(::Type{TwoLevelTree{S,T,OP}}) where {S,T,OP} = eltype(OP)
function Base.iterate(itr::TwoLevelTree, state = (1, nothing))
    i = state[1]
    n = itr.nodes[i]
    next = isnothing(state[2]) ? iterate(n.operational) : iterate(n.operational, state[2])
    if next === nothing
        i = i + 1
        if i > length(itr.nodes)
            return nothing
        end
        n = itr.nodes[i]
        next = iterate(n.operational)
    end
    return TreePeriod(n, next[1]), (i, next[2])
end

"""
	struct TreePeriod{P} <: TimePeriod where {P<:TimePeriod}

Time period for iteration of a `TwoLevelTree` time structure. This period has in addition
to an operational period also the two fields `branch` and `prob_branch` corresponding to the
respective branch and probability of the branch

!!! warn "Using OperationalScenarios"
    The probability will always only correspond to the branch probability, even when you
    utilize `OperationalScenarios`.  Using the function `probability` includes however the
    scenario probability.
"""
struct TreePeriod{P} <: TimePeriod where {P<:TimePeriod}
    sp::Int
    branch::Int
    prob_branch::Float64
    multiple::Float64
    period::P
end
_period(t::TreePeriod) = t.period

_strat_per(t::TreePeriod) = t.sp
_branch(t::TreePeriod) = t.branch
_rper(t::TreePeriod) = _rper(_period(t))
_opscen(t::TreePeriod) = _opscen(_period(t))
_oper(t::TreePeriod) = _oper(_period(t))

isfirst(t::TreePeriod) = isfirst(_period(t))
duration(t::TreePeriod) = duration(_period(t))
multiple(t::TreePeriod) = t.multiple
probability_branch(t::TreePeriod) = t.prob_branch
probability(t::TreePeriod) = probability(_period(t)) * probability_branch(t)

function Base.show(io::IO, t::TreePeriod)
    return print(io, "sp$(_strat_per(t))-br$(_branch(t))-$(_period(t))")
end
function Base.isless(t1::TreePeriod, t2::TreePeriod)
    return _strat_per(t1) < _strat_per(t2) || (_strat_per(t1) == _strat_per(t2) && _period(t1) < _period(t2))
end

# Convenient constructors for the individual types
function TreePeriod(n::StratNode, per::P) where {P<:Union{TimePeriod,TimeStructure}}
    mult = n.mult_sp * multiple(per)
    return TreePeriod(_strat_per(n), _branch(n), probability_branch(n), mult, per)
end
"""
    struct StrategicScenario

Desription of an individual strategic scenario. It includes all strategic nodes
corresponding to a scenario, including the probability. It can be utilized within a
decomposition algorithm.
"""
struct StrategicScenario
    probability::Float64
    nodes::Vector{<:StratNode}
end

# Iterate through strategic periods of scenario
Base.length(scen::StrategicScenario) = length(scen.nodes)
Base.last(scen::StrategicScenario) = last(scen.nodes)

function Base.iterate(scs::StrategicScenario, state = nothing)
    next = isnothing(state) ? iterate(scs.nodes) : iterate(scs.nodes, state)
    isnothing(next) && return nothing
    return next[1], next[2]
end

"""
    struct StrategicScenarios

Type for iteration through the individual strategic scenarios represented as
[`StrategicScenario`](@ref).
"""
struct StrategicScenarios
    ts::TwoLevelTree
end

"""
    strategic_scenarios(ts::TwoLevelTree)

This function returns a type for iterating through the individual strategic scenarios of a
`TwoLevelTree`. The type of the iterator is dependent on the type of the
input `TimeStructure`.

When the `TimeStructure` is a `TimeStructure`, `strategic_scenarios` returns a
"""
strategic_scenarios(two_level::TwoLevel) = [two_level]

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strategic_scenarios` returns the
iterator `StrategicScenarios`.
"""
strategic_scenarios(ts::TwoLevelTree) = StrategicScenarios(ts)
# Allow a TwoLevel structure to be used as a tree with one scenario
# TODO: Should be replaced with a single wrapper as it is the case for the other scenarios

Base.length(scens::StrategicScenarios) = nleaves(scens.ts)
function Base.iterate(scs::StrategicScenarios, state = 1)
    if state > nleaves(scs.ts)
        return nothing
    end

    node = getleaf(scs.ts, state)
    prob = probability_branch(node)
    nodes = [node]
    while !isnothing(node.parent)
        node = node.parent
        pushfirst!(nodes, node)
    end

    return StrategicScenario(prob, nodes), state + 1
end

"""
    add_node(
        tree::TwoLevelTree{T, StratNode{S, T, OP}},
        parent,
        sp,
        duration::S,
        branch_prob,
        branching,
        oper::OP,
    ) where {S, T, OP<:TimeStructure{T}}

Iterative addition of nodes.
"""
# Add nodes iteratively in a depth first manner
function add_node(
    tree::TwoLevelTree{S,T,StratNode{S,T,OP}},
    parent,
    sp,
    duration::S,
    branch_prob,
    branching,
    oper::OP,
) where {S,T,OP<:TimeStructure{T}}
    prob_branch = branch_prob * (isnothing(parent) ? 1.0 : parent.prob_branch)
    mult_sp = duration * tree.op_per_strat / _total_duration(oper)
    node = StratNode{S,T,OP}(
        sp,
        branches(tree, sp) + 1,
        duration,
        prob_branch,
        mult_sp,
        parent,
        oper,
    )
    push!(tree.nodes, node)
    if isnothing(parent)
        tree.root = node
    end

    if sp < tree.len
        for i in 1:branching[sp]
            # TODO: consider branching probability as input, but use uniform for now
            add_node(tree, node, sp + 1, duration, 1.0 / branching[sp], branching, oper)
        end
    end
end

"""
    regular_tree(
        duration::S,
        branching::Vector,
        ts::OP;
        op_per_strat::Real=1.0,
    ) where {S, T, OP<:TimeStructure{T}}

Function for creating a regular tree.
"""
function regular_tree(
    duration::S,
    branching::Vector,
    ts::OP;
    op_per_strat::Real = 1.0,
) where {S,T,OP<:TimeStructure{T}}
    tree = TwoLevelTree{S,T,StratNode{S,T,OP}}(Vector{StratNode{S,T,OP}}(), op_per_strat)
    tree.len = length(branching) + 1
    add_node(tree, nothing, 1, duration, 1.0, branching, ts)

    return tree
end

"""
    struct StratTreeNodes{S, T, OP} <: AbstractTreeStructure

Type for iterating through the individual strategic nodes of a [`TwoLevelTree`](@ref).
It is automatically created through the function [`strat_periods`](@ref), and hence,
[`strategic_periods`](@ref).

Iterating through `StratTreeNodes` using the `WithPrev` iterator changes the behaviour,
although the meaning remains unchanged.
"""
struct StratTreeNodes{S,T,OP} <: AbstractTreeStructure
    ts::TwoLevelTree{S,T,OP}
end

# Adding methods to existing Julia functions
Base.length(sps::StratTreeNodes) = length(sps.ts.nodes)
Base.eltype(_::Type{StratTreeNodes{T,OP}}) where {T,OP} = OP
function Base.iterate(stps::StratTreeNodes, state = nothing)
    next = isnothing(state) ? 1 : state + 1
    next == length(stps) + 1 && return nothing
    return stps.ts.nodes[next], next
end

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strat_periods` returns a
[`StratTreeNodes`](@ref) type, which, through iteration, provides [`StratNode`](@ref) types.

These are equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
strat_periods(ts::TwoLevelTree) = StratTreeNodes(ts)
