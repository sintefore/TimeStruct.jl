
abstract type AbstractTreeNode end

mutable struct TwoLevelTree <: TimeStructure
	len::Integer        
	root
    nodes::Vector
end

# Create empty tree
function TwoLevelTree() 
    return TwoLevelTree(0, nothing, Vector())
end

struct OperPeriod <: TimePeriod{TwoLevel}
	sp
    branch
	sc
	op
	duration
	prob
end

opscen(t::OperPeriod) = t.sc
strat_per(t::OperPeriod) = t.sp
branch(t::OperPeriod) = t.branch

Base.length(itr::TwoLevelTree) = sum(length(n.operational) for n in itr.nodes)
Base.eltype(::Type{TwoLevelTree}) = OperPeriod

# Iterate through all time periods as OperationalPeriods
function Base.iterate(itr::TwoLevelTree)
	spn = itr.nodes[1]
	next = iterate(spn.operational)
	next === nothing && return nothing
	per = next[1]
	return OperPeriod(spn.sp, spn.branch, opscen(per), per.op, per.duration, probability(spn) * probability(per)), (1, next[2])
end

function Base.iterate(itr::TwoLevelTree, state)
	i = state[1]
    spn = itr.nodes[i]
	next = iterate(spn.operational, state[2])
	if next === nothing
		i = i + 1
		if i > length(itr.nodes)
			return nothing
		end
        spn = itr.nodes[i]
		next = iterate(spn.operational)
	end
	per = next[1]
	return OperPeriod(spn.sp, spn.branch, opscen(per), per.op, per.duration , probability(spn) * probability(per)), (i,next[2])
end


struct TreeNode <: TimePeriod{TwoLevelTree}
    node
    sp 
    parent::Union{Nothing,TreeNode}
    branch
    duration
    probability::Float64
    operational::TimeStructure
end

Base.show(io::IO, n::TreeNode) = print(io, "n$(n.node)-sp$(n.sp)")
branch(n::TreeNode) = n.branch
strat_per(n::TreeNode) = n.sp
probability(n::TreeNode) = n.probability

children(n::TreeNode, ts::TwoLevelTree) = [c for c in ts.nodes if c.parent == n]
nchildren(n::TreeNode, ts::TwoLevelTree) = count(c -> c.parent == n, ts.nodes)
strat_nodes(ts::TwoLevelTree) = ts.nodes

# Iterate through time periods of a tree node
function Base.iterate(itr::TreeNode, state=nothing) 
	next = isnothing(state) ? iterate(itr.operational) : iterate(itr.operational, state)
	next === nothing && return nothing
	per = next[1]
	return OperPeriod(itr.sp, itr.branch, opscen(per), per.op, per.duration, itr.probability * probability(per)), next[2]
end

struct Scenario
    probability
    nodes::Vector{TreeNode}
end


# Iterate through all scenarios
struct Scenarios
    ts::TwoLevelTree
end

scenarios(ts::TwoLevelTree) = Scenarios(ts)

nleaves(ts::TwoLevelTree) = count(n -> nchildren(n,ts) == 0, ts.nodes)
leaves(ts::TwoLevelTree) = [n for n in ts.nodes if nchildren(n,ts) == 0]
getleaf(ts::TwoLevelTree, leaf) = leaves(ts)[leaf]  

Base.length(scens::Scenarios) = nleaves(scens.ts)
function Base.iterate(scs::Scenarios, state=1)
    if state > nleaves(scs.ts)
        return nothing
    end

    node = getleaf(scs.ts, state)
    prob = probability(node)
    nodes = [node]
    while !isnothing(node.parent)
        node = node.parent
        pushfirst!(nodes, node) 
    end
    
    return Scenario(prob, nodes), state+1
end

branches(tree::TwoLevelTree, sp) = count(n-> n.sp == sp, tree.nodes)

# Add nodes iteratively in a depth first manner
function add_node(tree::TwoLevelTree, parent, index, sp, duration, branch_prob, branching, ts::TimeStructure)
    prob = branch_prob * (isnothing(parent) ? 1.0 : parent.probability)
    node = TreeNode(index, sp, parent, branches(tree, sp) + 1, duration, prob, ts)
    push!(tree.nodes, node)
    if isnothing(parent)
        tree.root = node
    end

    if sp < tree.len
        for i in 1:branching[sp]
            # TODO: consider branching probability as input, but use uniform for now
            add_node(tree, node, length(tree.nodes) + 1, sp+1, duration, 1.0 / branching[sp], branching,ts)
        end
    end
end

# Create a regular tree with the given branching structure and the same time structure in each node 
function regular_tree(duration, branching::Vector, ts::TimeStructure)
    tree = TwoLevelTree()
    tree.len = length(branching) + 1
    add_node(tree, nothing, 1, 1, duration, 1.0, branching, ts)

    return tree
end