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
    mult_sp::Float64
    prob_branch::Float64
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
Base.last(n::StratNode) = TreePeriod(n, last(n.operational))
Base.eltype(::Type{StratNode{S,T,OP}}) where {S,T,OP} = TreePeriod{eltype(OP)}
function Base.iterate(n::StratNode, state = nothing)
    next = isnothing(state) ? iterate(n.operational) : iterate(n.operational, state)
    next === nothing && return nothing

    return TreePeriod(n, next[1]), next[2]
end

"""
    struct TreeNode{S,T,OP<:TimeStructure{T},COP<:Union{Nothing, TimeStructure{T}}}

    TreeNode(duration::Number, ts::TimeStructure)
    TreeNode(duration::Number, ts::TimeStructure, child::TreeNode)
    TreeNode(duration::Number, ts::TimeStructure, len::Int64, children::TreeNode)
    TreeNode(duration::Number, ts::TimeStructure, children::Vector{<:TreeNode})
    TreeNode(duration::Number, ts::TimeStructure, probability::Vector{<:Float64}, sub_tn::TreeNode)

A subtype introduced for creating all potential structures of a `TwoLevelTree`.

A `TreeNode` is similar to a [`StratNode`](@ref) but does not require the calculation of all
required parameters by the user. The parameters are automatically calculated when creating
a [`TwoLevelTree`](@ref) for a given `TreeNode`.

The TreeNode has a given `duration` which is similar to the `duration` of a [`TwoLevel`](@ref)
time structure and a single TimeStructure `ts`.

!!! note
    - The `TimeStructure` of the `TreeNode` and all children must use the same type for the
      duration, *.i.e.*, either Integer or Float.

## Constructors

The following constructors are included for the type:

- `TreeNode(duration::Number, ts::TimeStructure)`: the last `TreeNode` within a branch,
  *i.e.*, the leaf of the branch. It does not posess a child.
- `TreeNode(duration::Number, ts::TimeStructure, child::TreeNode)`: a `TreeNode` with only a
  single child. *i.e.*, a linear continuation.
- `TreeNode(duration::Number, ts::TimeStructure, len::Int64, children::TreeNode)`: a `TreeNode`
  with `len` children, each with the same structure and probability.
- `TreeNode(duration::Number, ts::TimeStructure, probability::Vector{<:Float64}, children::TreeNode)`:
  a `TreeNode` with `len` children, each with the same structure but a different probability.
- `TreeNode(duration::Number, ts::TimeStructure, children::Vector{<:TreeNode})` corresponds
  to a number of different children with different structures, but the same probability.
- `TreeNode(duration::Number, ts::TimeStructure, probability::Vector{<:Float64}, children::TreeNode)`:
  a `TreeNode` with `length(probability)` children, each with the same structure but a
  different probability.
- `TreeNode(duration::Number, ts::TimeStructure, probability::Vector{<:Float64}, children::Vector{<:TreeNode})`:
  a `TreeNode` with `length(probability)` children, each with a different structure and
  probability.

## Example

```julia
day = SimpleTimes(24, 1)
# Provides a leaf node
TreeNode(2, day)

# Provides a linear node structure
TreeNode(2, day, TreeNode(2, day))

# Provides a tree node with two children with 70 % and 30 % probability, respectively
TreeNode(2, day, [0.7, 0.3], TreeNode(2, SimpleTimes(24, 1)))


# Provide a tree node with two children with 70 % (168 periods) and 30 % (24 periods)
# probability, respectively
TreeNode(2, day, [0.7, 0.3], [
    TreeNode(2, SimpleTimes(168, 1)),
    TreeNode(2, SimpleTimes(24, 1)),
])
```
"""
struct TreeNode{S,T,OP<:TimeStructure{T},COP}
    duration::S
    ts::OP
    probability::Vector{Float64}
    children::Vector{COP}
    function TreeNode(
        duration::S,
        ts::OP,
        probability::Vector{Float64},
        children::Vector{COP},
    ) where {S,T,OP<:TimeStructure{T},COP}
        if length(probability) ≠ length(children)
            throw(
                ArgumentError(
                    "The length of `probability` must be equal to the length of `children`.",
                ),
            )
        elseif !isapprox(sum(probability), 1; atol = 1e-6)
            @warn(
                "The sum of the probability vector is given by $(sum(probability)). " *
                "This can lead to unexpected behavior."
            )
        end
        return new{S,T,OP,COP}(duration, ts, probability, children)
    end
end
# Constructor for the last TreeNode in a branch, i.e., the leaf
function TreeNode(duration::Number, ts::TimeStructure)
    return TreeNode(duration, ts, [1.0], [nothing])
end
# Constructor for a case in which the children time structure does not incorporate uncertainty
function TreeNode(duration::Number, ts::TimeStructure, child::TreeNode)
    return TreeNode(duration, ts, [1.0], [child])
end
# Constructor for a case in which all children are equal (time structure, children, and so on)
# and have the same probability
function TreeNode(duration::Number, ts::TimeStructure, len::Int64, children::TreeNode)
    return TreeNode(duration, ts, ones(len) ./ len, fill(children, len))
end
# Constructor for a case in which all children have the same probability
function TreeNode(duration::Number, ts::TimeStructure, children::Vector{<:TreeNode})
    len_children = length(children)
    return TreeNode(duration, ts, ones(len_children) ./ len_children, children)
end
# Constructor for a case in which all children are equal (time structure, children, and so on),
# but can have a different probability
function TreeNode(
    duration::Number,
    ts::TimeStructure,
    probability::Vector{<:Float64},
    children::TreeNode,
)
    len = length(probability)
    return TreeNode(duration, ts, probability, fill(children, len))
end

duration_strat(n::TreeNode) = n.duration
children(n::TreeNode) = n.children
