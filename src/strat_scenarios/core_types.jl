"""
    mutable struct TwoLevelTree{S,T,OP<:AbstractTreeNode{S,T}} <: TimeStructure{T}

    TwoLevelTree(node::TreeNode; op_per_strat=8760.0)
    TwoLevelTree(duration::S, branching::Vector, ts::OP; op_per_strat::Float64 = 1.0) where {S,T,OP<:TimeStructure{T}}

Time structure allowing for a tree structure for the strategic level. For each strategic
node in the tree a separate time structure is used for operational decisions. Iterating the
structure will go through all operational periods.

The default approach for creating a `TwoLevelTree` is by providing the root `[TreeNode`](@ref)
with all its children nodes. In the case of a regular structure, that is all children nodes
have the same `duration`, time structure `ts`, probability, and children itself, you can use
a simplified constructor with the `branching` vector. The vector `branching` specifies the
number of branchings at each stage of the tree, excluding the first stage. The branches at
each stage will all have equal probability, duration, and time structure.

!!! warning "Additional iteratores"
    `TwoLevelTree` utilize a separate [`withprev`](@ref) method which is equivalent to the
    existing method for the other time structures. [`withnext`](@ref), [`chunk](@ref) and
    [`chunk_duration`](@ref) are not implemented and will result in an error when used.

## Example

```julia
# Declare the individual time structure
day = SimpleTimes(24, 1)

# Regular tree with 3 strategic periods of duration 5, 3 branches for the second strategic
# period, and 6 branchs in the thirdand forth strategic period
regtree_1 = TwoLevelTree(5, [3, 2, 1], day)

# Equivalent structure using `TreeNode` and the different constructors
regtree_2 = TwoLevelTree(
    TreeNode(5, day, [
        TreeNode(5, day, 2,
            TreeNode(5, day, TreeNode(5, day))
        )
        TreeNode(5, day, [0.5, 0.5],
            TreeNode(5, day, TreeNode(5, day))
        )
        TreeNode(5, day, [
            TreeNode(5, day, TreeNode(5, day)),
            TreeNode(5, day, TreeNode(5, day)),
        ])
    ])
)
```
"""
mutable struct TwoLevelTree{S,T,OP<:AbstractTreeNode{S,T}} <: TimeStructure{T}
    len::Int
    root::Any
    nodes::Vector{OP}
    op_per_strat::Float64
end
function TwoLevelTree(parent::TreeNode; op_per_strat = 1.0)
    nodes = StratNode[]

    add_node!(nodes, parent, nothing, 1.0, 1, op_per_strat)
    nodes = convert(Array{typejoin(typeof.(nodes)...)}, nodes)
    len = maximum([_strat_per(sn) for sn in nodes])

    return TwoLevelTree(len, nodes[1], nodes, op_per_strat)
end
function TwoLevelTree(
    duration::S,
    branching::Vector,
    ts::OP;
    op_per_strat::Float64 = 1.0,
) where {S,T,OP<:TimeStructure{T}}
    node = TreeNode(duration, ts)
    for k in reverse(branching)
        node = TreeNode(duration, ts, k, node)
    end
    return TwoLevelTree(node; op_per_strat)
end

function _multiple_adj(itr::TwoLevelTree, n::Int)
    mult =
        itr.nodes[n].duration * itr.op_per_strat / _total_duration(itr.nodes[n].operational)
    return stripunit(mult)
end
strat_nodes(ts::TwoLevelTree) = ts.nodes

n_strat_per(ts::TwoLevelTree) = maximum(_strat_per(c) for c in strat_nodes(ts))
n_children(n::StratNode, ts::TwoLevelTree) = count(c -> _parent(c) == n, strat_nodes(ts))
n_leaves(ts::TwoLevelTree) = count(n -> n_children(n, ts) == 0, strat_nodes(ts))
n_branches(ts::TwoLevelTree, sp::Int) = count(n -> _strat_per(n) == sp, strat_nodes(ts))

children(n::StratNode, ts::TwoLevelTree) = [c for c in ts.nodes if _parent(c) == n]
leaves(ts::TwoLevelTree) = [n for n in strat_nodes(ts) if n_children(n, ts) == 0]

get_leaf(ts::TwoLevelTree, leaf::Int) = leaves(ts)[leaf]
function get_strat_node(ts::TwoLevelTree, sp::Int, branch::Int)
    node = filter(n -> _strat_per(n) == sp && _branch(n) == branch, strat_nodes(ts))
    if isempty(node)
        throw(
            ErrorException(
                "The `TwoLevelTree` does not have a node with strategic period $(sp) and branch $(branch)",
            ),
        )
    else
        return node[1]
    end
end

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
    period::P
    multiple::Float64
    prob_branch::Float64
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
    return _strat_per(t1) < _strat_per(t2) ||
           (_strat_per(t1) == _strat_per(t2) && _period(t1) < _period(t2))
end

# Convenient constructors for the individual types
function TreePeriod(n::StratNode, per::TimePeriod)
    mult = n.mult_sp * multiple(per)
    return TreePeriod(_strat_per(n), _branch(n), per, mult, probability_branch(n))
end
"""
    struct StrategicScenario

Description of an individual strategic scenario. It includes all strategic nodes
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
iterator `StrategicScenarios`.
"""
strategic_scenarios(ts::TwoLevelTree) = StrategicScenarios(ts)
# Allow a TwoLevel structure to be used as a tree with one scenario
# TODO: Should be replaced with a single wrapper as it is the case for the other scenarios

Base.length(scens::StrategicScenarios) = n_leaves(scens.ts)
function Base.iterate(scs::StrategicScenarios, state = 1)
    if state > n_leaves(scs.ts)
        return nothing
    end

    node = get_leaf(scs.ts, state)
    prob = probability_branch(node)
    nodes = [node]
    while !isnothing(_parent(node))
        node = _parent(node)
        pushfirst!(nodes, node)
    end

    return StrategicScenario(prob, nodes), state + 1
end

"""
    add_node!(
        nodes::Vector{<:StratNode},
        node::TreeNode{S, T, OP, U},
        parent::Union{Nothing,StratNode},
        prob::Float64,
        sp::Int64,
        op_per_strat::Real,
    ) where {S,T,OP<:TimeStructure{T},U}

Iterative addition of a `TreeNode` `node` to a `Vector{<:StratNode}` .
"""
# Ignored docstring, just fyi in this case
function add_node!(
    nodes::Vector{<:StratNode},
    node::TreeNode{S,T,OP,U},
    parent::Union{Nothing,StratNode},
    prob::Float64,
    sp::Int64,
    op_per_strat::Real,
) where {S,T,OP<:TimeStructure{T},U}
    oper = node.ts
    new_node = StratNode(
        sp,
        count(n -> _strat_per(n) == sp, nodes) + 1,
        duration_strat(node),
        duration_strat(node) * op_per_strat / _total_duration(oper),
        prob,
        parent,
        oper,
    )
    push!(nodes, new_node)

    # Iterate through the children and add their nodes
    for (sub_prob, sub_tn) in zip(node.probability, children(node))
        # Continue when reaching leaf node
        isnothing(sub_tn) && continue

        # Add the new node
        total_prob = prob * sub_prob
        add_node!(nodes, sub_tn, new_node, total_prob, sp + 1, op_per_strat)
    end
end

"""
    regular_tree(
        duration::S,
        branching::Vector,
        ts::OP;
        op_per_strat::Real=1.0,
    ) where {S,T,OP<:TimeStructure{T}}

Function for creating a regular tree with a uniform structure for each strategic period.

Each strategic period is of equal length as given by `duration` and will have the same
operational time structure `ts`. The vector `branching` specifies the number of branchings
at each stage of the tree, excluding the first stage. The branches at each stage will
all have equal probability.

!!! note "Deprecated function"
    This function is deprecated and will be removed in a later release. The new function is
    given by

    ```julia
    TwoLevelTree(duration, branching, ts; op_per_strat)
    ```

"""
function regular_tree(
    duration::S,
    branching::Vector,
    ts::OP;
    op_per_strat::Real = 1.0,
) where {S,T,OP<:TimeStructure{T}}
    op_per_strat = convert(Float64, op_per_strat)
    return TwoLevelTree(duration, branching, ts; op_per_strat)
end

"""
    struct StratTreeNodes{S,T,OP<:TimeStructure{T}} <: AbstractStratPers{T}

Type for iterating through the individual strategic nodes of a [`TwoLevelTree`](@ref).
It is automatically created through the function [`strat_periods`](@ref), and hence,
[`strategic_periods`](@ref).

Iterating through `StratTreeNodes` using the `WithPrev` iterator changes the behaviour,
although the meaning remains unchanged.
"""
struct StratTreeNodes{S,T,OP<:TimeStructure{T}} <: AbstractStratPers{T}
    ts::TwoLevelTree{S,T,OP}
end

# Adding methods to existing Julia functions
Base.length(sps::StratTreeNodes) = length(sps.ts.nodes)
Base.eltype(_::Type{StratTreeNodes{S,T,OP}}) where {S,T,OP} = OP
function Base.iterate(stps::StratTreeNodes, state = nothing)
    next = isnothing(state) ? 1 : state + 1
    next == length(stps) + 1 && return nothing
    return stps.ts.nodes[next], next
end
function Base.getindex(sps::StratTreeNodes, index::Int)
    return sps.ts.nodes[index]
end

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `strat_periods` returns a
[`StratTreeNodes`](@ref) type, which, through iteration, provides [`StratNode`](@ref) types.

These are equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
strat_periods(ts::TwoLevelTree) = StratTreeNodes(ts)
