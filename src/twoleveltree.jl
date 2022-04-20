
abstract type AbstractTreeNode{T} end

mutable struct TwoLevelTree{T} <: TimeStructure{T}
    len::Int
    root::Any
    nodes::Vector{<:AbstractTreeNode{T}}
end

function TwoLevelTree{T}(nodes::Vector{<:AbstractTreeNode}) where {T}
    return TwoLevelTree{T}(0, nothing, nodes)
end

struct OperPeriod <: TimePeriod{TwoLevel}
    sp::Any
    branch::Any
    sc::Any
    op::Any
    duration::Any
    prob::Any
end

_oper(t::OperPeriod) = t.op
_opscen(t::OperPeriod) = t.sc
_strat_per(t::OperPeriod) = t.sp
_branch(t::OperPeriod) = t.branch

function Base.length(itr::TwoLevelTree)
    return sum(length(n.strat_node.operational) for n in itr.nodes)
end
Base.eltype(::Type{TwoLevelTree}) = OperPeriod

# Iterate through all time periods as OperationalPeriods
function Base.iterate(itr::TwoLevelTree)
    spn = itr.nodes[1].strat_node
    next = iterate(spn.operational)
    next === nothing && return nothing
    per = next[1]
    return OperPeriod(
        spn.sp,
        spn.branch,
        _opscen(per),
        per.op,
        per.duration,
        probability(spn) * probability(per),
    ),
    (1, next[2])
end

function Base.iterate(itr::TwoLevelTree, state)
    i = state[1]
    spn = itr.nodes[i].strat_node
    next = iterate(spn.operational, state[2])
    if next === nothing
        i = i + 1
        if i > length(itr.nodes)
            return nothing
        end
        spn = itr.nodes[i].strat_node
        next = iterate(spn.operational)
    end
    per = next[1]
    return OperPeriod(
        spn.sp,
        spn.branch,
        _opscen(per),
        per.op,
        per.duration,
        probability(spn) * probability(per),
    ),
    (i, next[2])
end

struct StratNode{T} <: TimePeriod{TwoLevelTree}
    sp::Int
    branch::Int
    duration::Duration
    probability::Float64
    operational::TimeStructure{T}
end

Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
_branch(n::StratNode) = n.branch
_strat_per(n::StratNode) = n.sp
probability(n::StratNode) = n.probability
duration(n::StratNode) = n.duration

struct TreeNode{T} <: AbstractTreeNode{T}
    node::Int
    parent::Union{Nothing,TreeNode}
    strat_node::StratNode{T}
end

children(n::TreeNode, ts::TwoLevelTree) = [c for c in ts.nodes if c.parent == n]
nchildren(n::TreeNode, ts::TwoLevelTree) = count(c -> c.parent == n, ts.nodes)
strat_nodes(ts::TwoLevelTree) = [n.strat_node for n in ts.nodes]

# Iterate through time periods of a strategic node
function Base.iterate(itr::StratNode, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]
    return OperPeriod(
        itr.sp,
        itr.branch,
        _opscen(per),
        per.op,
        per.duration,
        itr.probability * probability(per),
    ),
    next[2]
end

struct Scenario
    probability::Any
    nodes::Vector{TreeNode}
end

# Iterate through all scenarios
struct Scenarios
    ts::TwoLevelTree
end

scenarios(ts::TwoLevelTree) = Scenarios(ts)

nleaves(ts::TwoLevelTree) = count(n -> nchildren(n, ts) == 0, ts.nodes)
leaves(ts::TwoLevelTree) = [n for n in ts.nodes if nchildren(n, ts) == 0]
getleaf(ts::TwoLevelTree, leaf) = leaves(ts)[leaf]

Base.length(scens::Scenarios) = nleaves(scens.ts)
function Base.iterate(scs::Scenarios, state = 1)
    if state > nleaves(scs.ts)
        return nothing
    end

    node = getleaf(scs.ts, state)
    prob = probability(node.strat_node)
    nodes = [node]
    while !isnothing(node.parent)
        node = node.parent
        pushfirst!(nodes, node)
    end

    return Scenario(prob, nodes), state + 1
end

branches(tree::TwoLevelTree, sp) = count(n -> n.strat_node.sp == sp, tree.nodes)

# Add nodes iteratively in a depth first manner
function add_node(
    tree::TwoLevelTree{T},
    parent,
    index,
    sp,
    duration,
    branch_prob,
    branching,
    ts::TimeStructure{T},
) where {T}
    prob =
        branch_prob * (isnothing(parent) ? 1.0 : parent.strat_node.probability)
    node = TreeNode{T}(
        index,
        parent,
        StratNode{T}(sp, branches(tree, sp) + 1, duration, prob, ts),
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
                length(tree.nodes) + 1,
                sp + 1,
                duration,
                1.0 / branching[sp],
                branching,
                ts,
            )
        end
    end
end

# Create a regular tree with the given branching structure and the same time structure in each node 
function regular_tree(
    duration,
    branching::Vector,
    ts::TimeStructure{T},
) where {T}
    tree = TwoLevelTree{T}(Vector{TreeNode{T}}())
    tree.len = length(branching) + 1
    add_node(tree, nothing, 1, 1, duration, 1.0, branching, ts)

    return tree
end
