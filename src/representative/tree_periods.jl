"""
    struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A structure representing a single representative period of a [`StratNode`](@ref) of a
[`TwoLevelTree`](@ref). It is created through iterating through [`StratNodeReprPers`](@ref).

It is equivalent to a [`StratReprPeriod`](@ref) of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwoLevelTree`](@ref).
"""
struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}
    sp::Int
    branch::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    operational::OP
end

_strat_per(rp::StratNodeReprPeriod) = rp.sp
_branch(rp::StratNodeReprPeriod) = rp.branch
_rper(rp::StratNodeReprPeriod) = rp.rp

mult_strat(rp::StratNodeReprPeriod) = rp.mult_sp
mult_repr(rp::StratNodeReprPeriod) = rp.mult_rp
function multiple(rp::StratNodeReprPeriod, t::OperationalPeriod)
    return t.multiple / rp.mult_sp
end
probability_branch(rp::StratNodeReprPeriod) = rp.prob_branch
probability(rp::StratNodeReprPeriod) = rp.prob_branch

StrategicTreeIndexable(::Type{<:StratNodeReprPeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprPeriod}) = HasStratIndex()

# Provide a constructor to simplify the design
function TreePeriod(
    rp::StratNodeReprPeriod,
    per::TimePeriod,
)
    mult = mult_strat(rp) * multiple(per)
    return TreePeriod(_strat_per(rp), _branch(rp), per, mult, probability_branch(rp))
end

# Adding methods to existing Julia functions
function Base.show(io::IO, rp::StratNodeReprPeriod)
    return print(io, "sp$(_strat_per(rp))-br$(_branch(rp))-rp$(_rper(rp))")
end
Base.eltype(_::StratNodeReprPeriod{T,OP}) where {T,OP} = TreePeriod{eltype(op)}

"""
    struct StratNodeReprPers{T,OP<:TimeStructInnerIter{T}} <: AbstractTreeStructure{T}

Type for iterating through the individual presentative periods of a [`StratNode`](@ref).
It is automatically created through the function [`repr_periods`](@ref).
"""
struct StratNodeReprPers{T,OP<:TimeStructInnerIter{T}} <: AbstractTreeStructure{T}
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    repr::OP
end

_strat_per(rps::StratNodeReprPers) = rps.sp
_branch(rps::StratNodeReprPers) = rps.branch

mult_strat(rps::StratNodeReprPers) = rps.mult_sp
probability_branch(rps::StratNodeReprPers) = rps.prob_branch

_oper_struct(rps::StratNodeReprPers) = rps.repr

"""
When the `TimeStructure` is a [`StratNode`](@ref), `repr_periods` returns the iterator
[`StratNodeReprPers`](@ref).
"""
function repr_periods(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeReprPers(
        _strat_per(n),
        _branch(n),
        mult_strat(n),
        probability_branch(n),
        repr_periods(n.operational),
    )
end

function strat_node_period(rps::StratNodeReprPers, next, state)
    return StratNodeReprPeriod(
        _strat_per(rps),
        _branch(rps),
        state,
        mult_strat(rps),
        mult_repr(next),
        probability_branch(rps),
        next,
    )
end

Base.eltype(_::StratNodeReprPers) = StratNodeReprPeriod

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `repr_periods` returns an `Array` of
all [`StratNodeReprPeriod`](@ref)s.

These are equivalent to a [`StratReprPeriod`](@ref) of a [`TwoLevel`](@ref) time structure.
"""
function repr_periods(ts::TwoLevelTree)
    return collect(Iterators.flatten(repr_periods(sp) for sp in strat_periods(ts)))
end
