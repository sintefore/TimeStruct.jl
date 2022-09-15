
abstract type AbstractTreeNode{T} end

"""
    mutable struct TwoLevelTree{T} <: TimeStructure{T}

    Time structure allowing for a tree structure for 
    the strategic level. 

    For each strategic node in the tree a separate time structure is used for 
    operational decisions. Iterating the structure will go through all operational periods.
"""
mutable struct TwoLevelTree{T} <: TimeStructure{T}
    len::Int
    root::Any
    nodes::Vector{<:AbstractTreeNode{T}}
end

function TwoLevelTree{T}(nodes::Vector{<:AbstractTreeNode}) where {T}
    return TwoLevelTree{T}(0, nothing, nodes)
end

"""
	struct OperPeriod <: TimePeriod

    Time period for iteration of a TwoLevelTree time structure. 
"""
struct OperPeriod <: TimePeriod
    sp::Int
    branch::Int
    sc::Int
    op::Int
    duration::Float64
    prob::Float64
end

duration(t::OperPeriod) = t.duration
probability(t::OperPeriod) = t.prob
_oper(t::OperPeriod) = t.op
_opscen(t::OperPeriod) = t.sc
_strat_per(t::OperPeriod) = t.sp
_branch(t::OperPeriod) = t.branch

function Base.length(itr::TwoLevelTree)
    return sum(length(n.strat_node.operational) for n in itr.nodes)
end
Base.eltype(::Type{TwoLevelTree{T}}) where {T} = OperPeriod

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
        _oper(per),
        duration(per),
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
        _oper(per),
        duration(per),
        probability(spn) * probability(per),
    ),
    (i, next[2])
end

struct StratNode{T} <: TimePeriod
    sp::Int
    branch::Int
    duration::Duration
    probability::Float64
    operational::TimeStructure{T}
    time_struct::TimeStructure
end

Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
_branch(n::StratNode) = n.branch
_strat_per(n::StratNode) = n.sp
probability(n::StratNode) = n.probability
duration(n::StratNode) = n.duration

isfirst(n::StratNode) = n.sp == 1

struct TreeNode{T} <: AbstractTreeNode{T}
    node::Int
    parent::Union{Nothing,TreeNode}
    strat_node::StratNode{T}
end

children(n::TreeNode, ts::TwoLevelTree) = [c for c in ts.nodes if c.parent == n]
nchildren(n::TreeNode, ts::TwoLevelTree) = count(c -> c.parent == n, ts.nodes)
strat_nodes(ts::TwoLevelTree) = [n.strat_node for n in ts.nodes]
strat_periods(ts::TwoLevelTree) = strat_nodes(ts)

# Iterate through time periods of a strategic node
Base.length(n::StratNode) = length(n.operational)
Base.eltype(::Type{StratNode{T}}) where {T} = OperPeriod
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
        _oper(per),
        duration(per),
        itr.probability * probability(per),
    ),
    next[2]
end

struct StratNodeOperationalScenario{T} <: TimeStructure{T}
    node::StratNode
    scen::Int
    probability::Float64
    operational::TimeStructure{T}
end

# Iteration through all time periods in an operational scenario of a strategic node
Base.length(snops::StratNodeOperationalScenario) = length(snops.operational)
Base.eltype(_::StratNodeOperationalScenario) = OperPeriod
function Base.iterate(snops::StratNodeOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(snops.operational) :
        iterate(snops.operational, state)
    isnothing(next) && return nothing
    per = next[1]
    return OperPeriod(
        snops.node.sp,
        snops.node.branch,
        snops.scen,
        _oper(per),
        duration(per),
        snops.probability,
    ),
    next[2]
end

# Iterate through operational scenarios of a strategic node
struct StratNodeOpScens{TS}
    node::StratNode
    operational::TS
end

opscenarios(n::StratNode) = StratNodeOpScens(n, n.operational)

function Base.length(sops::StratNodeOpScens{OperationalScenarios{T}}) where {T}
    return sops.operational.len
end
function Base.iterate(
    sops::StratNodeOpScens{OperationalScenarios{T}},
    state = 1,
) where {T}
    state > sops.operational.len && return nothing
    return StratNodeOperationalScenario(
        sops.node,
        state,
        sops.node.probability * sops.operational.probability[state],
        sops.operational.scenarios[state],
    ),
    state + 1
end

function Base.length(sops::StratNodeOpScens{SimpleTimes{T}}) where {T}
    return 1
end
function Base.iterate(
    sops::StratNodeOpScens{SimpleTimes{T}},
    state = 1,
) where {T}
    state > 1 && return nothing
    return StratNodeOperationalScenario(
        sops.node,
        state,
        sops.node.probability,
        sops.operational,
    ),
    state + 1
end

struct Scenario
    probability::Float64
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

# Iterate through strategic periods of scenario
Base.length(scen::Scenario) = length(scen.nodes)
function Base.iterate(scs::Scenario, state = nothing)
    next = isnothing(state) ? iterate(scs.nodes) : iterate(scs.nodes, state)
    isnothing(next) && return nothing
    return next[1].strat_node, next[2]
end

branches(tree::TwoLevelTree, sp) = count(n -> n.strat_node.sp == sp, tree.nodes)

# Allow a TwoLevel structure to be used as a tree with one scenario
scenarios(two_level::TwoLevel{S,T}) where {S,T} = [two_level]

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
        StratNode{T}(sp, branches(tree, sp) + 1, duration, prob, ts, tree),
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
