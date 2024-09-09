
"""
    mutable struct TwoLevelTree{T} <: TimeStructure{T}

Time structure allowing for a tree structure for the strategic level.

For each strategic node in the tree a separate time structure is used for
operational decisions. Iterating the structure will go through all operational periods.
"""
mutable struct TwoLevelTree{T,OP<:AbstractTreeNode{T}} <: TimeStructure{T}
    len::Int
    root::Any
    nodes::Vector{OP}
    op_per_strat::Float64
end

function TwoLevelTree{T,OP}(
    nodes::Vector{OP},
    op_per_strat,
) where {T,OP<:AbstractTreeNode{T}}
    return TwoLevelTree{T,OP}(0, nothing, nodes, op_per_strat)
end

function Base.length(itr::TwoLevelTree)
    return sum(length(n.operational) for n in itr.nodes)
end
Base.eltype(::Type{TwoLevelTree{T,OP}}) where {T,OP} = TreePeriod

function _multiple_adj(itr::TwoLevelTree, n)
    mult =
        itr.nodes[n].duration * itr.op_per_strat /
        _total_duration(itr.nodes[n].operational)
    return stripunit(mult)
end
strat_nodes(tree::TwoLevelTree) = tree.nodes

function children(n::StratNode, ts::TwoLevelTree)
    return [c for c in ts.nodes if c.parent == n]
end
nchildren(n::StratNode, ts::TwoLevelTree) = count(c -> c.parent == n, ts.nodes)

branches(tree::TwoLevelTree, sp) = count(n -> n.sp == sp, tree.nodes)

leaves(ts::TwoLevelTree) = [n for n in ts.nodes if nchildren(n, ts) == 0]
nleaves(ts::TwoLevelTree) = count(n -> nchildren(n, ts) == 0, ts.nodes)
getleaf(ts::TwoLevelTree, leaf) = leaves(ts)[leaf]

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

isfirst(t::TreePeriod) = isfirst(t.period)
duration(t::TreePeriod) = duration(t.period)
probability_branch(t::TreePeriod) = t.prob_branch
probability(t::TreePeriod) = probability(t.period) * probability_branch(t)
multiple(t::TreePeriod) = t.multiple

_oper(t::TreePeriod) = _oper(t.period)
_opscen(t::TreePeriod) = _opscen(t.period)
_rper(t::TreePeriod) = _rper(t.period)
_branch(t::TreePeriod) = t.branch
_strat_per(t::TreePeriod) = t.sp

function Base.show(io::IO, t::TreePeriod)
    return print(io, "sp$(t.sp)-br$(t.branch)-$(t.period)")
end
function Base.isless(t1::TreePeriod, t2::TreePeriod)
    return t1.period < t2.period
end

function Base.iterate(itr::TwoLevelTree, state = (1, nothing))
    i = state[1]
    spn = itr.nodes[i]
    next =
        isnothing(state[2]) ? iterate(spn.operational) :
        iterate(spn.operational, state[2])
    if next === nothing
        i = i + 1
        if i > length(itr.nodes)
            return nothing
        end
        spn = itr.nodes[i]
        next = iterate(spn.operational)
    end
    per = next[1]

    mult = _multiple_adj(itr, i) * multiple(per)
    return TreePeriod(spn.sp, spn.branch, probability_branch(spn), mult, per),
    (i, next[2])
end

# Convenient constructors for the individual types
function TreePeriod(
    n::StratNode,
    per::P,
) where {P<:Union{TimePeriod,TimeStructure}}
    mult = n.mult_sp * multiple(per)
    return TreePeriod(n.sp, n.branch, n.prob_branch, mult, per)
end
function TreePeriod(
    osc::StratNodeOperationalScenario,
    per::P,
) where {P<:Union{TimePeriod,AbstractOperationalScenario}}
    mult = osc.mult_sp * multiple(per)
    return TreePeriod(osc.sp, osc.branch, osc.prob_branch, mult, per)
end
function TreePeriod(
    rp::StratNodeReprPeriod,
    per::P,
) where {P<:Union{TimePeriod,AbstractRepresentativePeriod}}
    mult = rp.mult_sp * multiple(per)
    return TreePeriod(rp.sp, rp.branch, rp.prob_branch, mult, per)
end
function TreePeriod(
    osc::StratNodeReprOpscenario,
    per::P,
) where {P<:Union{TimePeriod,AbstractOperationalScenario}}
    rper = ReprPeriod(osc.rp, per, osc.mult_rp * multiple(per))
    mult = osc.mult_sp * osc.mult_rp * multiple(per)
    return TreePeriod(osc.sp, osc.branch, osc.prob_branch, mult, rper)
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
strategic_scenarios(ts::TwoLevelTree) = StrategicScenarios(ts)
# Allow a TwoLevel structure to be used as a tree with one scenario
# TODO: Should be replaced with a single wrapper as it is the case for the other scenarios
strategic_scenarios(two_level::TwoLevel{S,T}) where {S,T} = [two_level]

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
    tree::TwoLevelTree{T,StratNode{S,T,OP}},
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
            add_node(
                tree,
                node,
                sp + 1,
                duration,
                1.0 / branching[sp],
                branching,
                oper,
            )
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
    tree = TwoLevelTree{T,StratNode{S,T,OP}}(
        Vector{StratNode{S,T,OP}}(),
        op_per_strat,
    )
    tree.len = length(branching) + 1
    add_node(tree, nothing, 1, duration, 1.0, branching, ts)

    return tree
end

"""
    struct StratTreeNodes{T, OP} <: AbstractTreeStructure

Type for iterating through the individual strategic nodes of a [`TwoLevelTree`](@ref).
It is automatically created through the function [`strat_periods`](@ref), and hence,
[`strategic_periods`](@ref).

Iterating through `StratTreeNodes` using the WithPrev iterator changes the behaviour,
although the meaining remains unchanged.
"""
struct StratTreeNodes{T,OP} <: AbstractTreeStructure
    ts::TwoLevelTree{T,OP}
end

# Adding methods to existing Julia functions
Base.length(sps::StratTreeNodes) = length(sps.ts.nodes)
Base.eltype(_::Type{StratTreeNodes{T,OP}}) where {T,OP} = OP
function Base.iterate(stps::StratTreeNodes, state = nothing)
    next = isnothing(state) ? 1 : state + 1
    next == length(stps) + 1 && return nothing
    return stps.ts.nodes[next], next
end

function Base.iterate(w::WithPrev{StratTreeNodes{T,OP}}) where {T,OP}
    n = iterate(w.itr)
    n === nothing && return n
    return (nothing, n[1]), (n[1], n[2])
end

function Base.iterate(w::WithPrev{StratTreeNodes{T,OP}}, state) where {T,OP}
    n = iterate(w.itr, state[2])
    n === nothing && return n
    return (n[1].parent, n[1]), (n[1], n[2])
end

"""
    strat_periods(ts::TwoLevelTree)

When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strat_periods` returns a
[`StratTreeNodes`](@ref) type, which, through iteration, provides [`StratNode`](@ref) types.

These are equivalent of a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
strat_periods(ts::TwoLevelTree) = StratTreeNodes(ts)

"""
    opscenarios(ts::TwoLevelTree)

When the `TimeStructure` is a [`TwoLevelTree`](@ref), `opscenarios` returns an `Array` of
all [`StratNodeOperationalScenario`](@ref)s or [`StratNodeReprOpscenario`](@ref)s types,
dependening on whether the [`TwoLevelTree`](@ref) includes [`RepresentativePeriods`](@ref)
or not.

These are equivalent of a [`StratOperationalScenario`](@ref) of a [`TwoLevel`](@ref) time
structure.
"""
function opscenarios(ts::TwoLevelTree)
    return collect(
        Iterators.flatten(opscenarios(sp) for sp in strategic_periods(ts)),
    )
end
function opscenarios(
    ts::TwoLevelTree{T,StratNode{S,T,OP}},
) where {S,T,OP<:RepresentativePeriods}
    return collect(
        Iterators.flatten(
            opscenarios(rp) for sp in strategic_periods(ts) for
            rp in repr_periods(sp)
        ),
    )
end

"""
    repr_periods(ts::TwoLevelTree)

When the `TimeStructure` is a [`TwoLevelTree`](@ref), `repr_periods` returns an `Array` of
all [`StratNodeReprPeriod`](@ref)s.

These are equivalent of a [`StratReprPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
function repr_periods(ts::TwoLevelTree)
    return collect(
        Iterators.flatten(repr_periods(sp) for sp in strategic_periods(ts)),
    )
end
