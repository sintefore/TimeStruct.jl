"""
    AbstractTreeNode{S,T} <: AbstractStrategicPeriod{S,T}

Abstract base type for all tree nodes within a [`TwoLevelTree`] type.
"""
abstract type AbstractTreeNode{S,T} <: AbstractStrategicPeriod{S,T} end

"""
    AbstractTreeStructure

Abstract base type for all tree timestructures within a [`TwoLevelTree`] type.
"""
abstract type AbstractTreeStructure end

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

A structure representing a single strategic node of a [`TwolevelTree`]. It is created
through iterating through [`StratTreeNodes`](@ref).

It is equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwolevelTree`].
"""
struct StratNode{S,T,OP<:TimeStructure{T}} <: AbstractTreeNode{S,T}
    sp::Int
    branch::Int
    duration::S
    prob_branch::Float64
    mult_sp::Float64
    parent::Any
    operational::OP
end

_strat_per(n::StratNode) = n.sp
_branch(n::StratNode) = n.branch

probability_branch(n::StratNode) = n.prob_branch
duration_strat(n::StratNode) = n.duration
multiple_strat(sp::StratNode, t) = multiple(t) / duration_strat(sp)

isfirst(n::StratNode) = n.sp == 1

# Adding methods to existing Julia functions
Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
Base.length(n::StratNode) = length(n.operational)
Base.eltype(::Type{StratNode}) = TreePeriod
function Base.iterate(n::StratNode, state = nothing)
    next =
        isnothing(state) ? iterate(n.operational) :
        iterate(n.operational, state)
    next === nothing && return nothing

    return TreePeriod(n, next[1]), next[2]
end

"""
    struct StratNodeOperationalScenario{T,OP<:TimeStructure{T}}  <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a strategic node supporting
iteration over its time periods. It is created through iterating through
[`StratNodeOpScens`](@ref).

It is equivalent to a [`StratOperationalScenario`](@ref) of a [`TwoLevel`](@ref) time
structure when utilizing a [`TwolevelTree`].
"""
struct StratNodeOperationalScenario{T,OP<:TimeStructure{T}} <:
       AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::OP
end

_opscen(osc::StratNodeOperationalScenario) = osc.scen
_branch(osc::StratNodeOperationalScenario) = osc.branch
_strat_per(osc::StratNodeOperationalScenario) = osc.sp

probability(osc::StratNodeOperationalScenario) = osc.prob_branch * prob_scen
probability_branch(osc::StratNodeOperationalScenario) = osc.prob_branch
mult_scen(osc::StratNodeOperationalScenario) = osc.mult_scen

function StrategicTreeIndexable(::Type{<:StratNodeOperationalScenario})
    return HasStratTreeIndex()
end
StrategicIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, osc::StratNodeOperationalScenario)
    return print(io, "sp$(osc.sp)-br$(osc.branch)-sc$(osc.scen)")
end
Base.eltype(_::StratNodeOperationalScenario) = TreePeriod

"""
    struct StratNodeOpScens <: AbstractTreeStructure

Type for iterating through the individual operational scenarios of a [`StratNode`](@ref).
It is automatically created through the function [`opscenarios`](@ref).
"""
struct StratNodeOpScens <: AbstractTreeStructure
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    opscens::Any
end

"""
    opscenarios(sp::StratNode{S,T,OP})

When the `TimeStructure` is a [`StratNode`](@ref), `opscenarios` returns a
[`StratNodeOpScens`](@ref) used for iterating through the individual operational scenarios
"""
function opscenarios(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(
        _strat_per(n),
        _branch(n),
        n.mult_sp,
        probability_branch(n),
        opscenarios(n.operational),
    )
end
function opscenarios(n::StratNode{S,T,OP}) where {S,T,OP<:RepresentativePeriods}
    return collect(Iterators.flatten(opscenarios(rp) for rp in repr_periods(n)))
end

_oper_struct(oscs::StratNodeOpScens) = oscs.opscens
function strat_node_period(oscs::StratNodeOpScens, next, state)
    return StratNodeOperationalScenario(
        oscs.sp,
        oscs.branch,
        state,
        oscs.mult_sp,
        mult_scen(next),
        oscs.prob_branch,
        probability(next),
        next,
    )
end

Base.eltype(_::StratNodeOpScens) = StratNodeOperationalScenario

"""
    struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A structure representing a single representative period of a [`StratNode`](@ref) of a
[`TwolevelTree`]. It is created through iterating through [`StratNodeReprPeriods`](@ref).

It is equivalent to a [`StratReprPeriod`] of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwolevelTree`].
"""
struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <:
       AbstractRepresentativePeriod{T}
    sp::Int
    branch::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    operational::OP
end

_rper(rp::StratNodeReprPeriod) = rp.rp
_branch(rp::StratNodeReprPeriod) = rp.branch
_strat_per(rp::StratNodeReprPeriod) = rp.sp

probability(rp::StratNodeReprPeriod) = rp.prob_branch
probability_branch(rp::StratNodeReprPeriod) = rp.prob_branch
function multiple(rp::StratNodeReprPeriod, t::OperationalPeriod)
    return t.multiple / rp.mult_sp
end

StrategicTreeIndexable(::Type{<:StratNodeReprPeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprPeriod}) = HasStratIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, rp::StratNodeReprPeriod)
    return print(io, "sp$(rp.sp)-br$(rp.branch)-rp$(rp.rp)")
end
Base.eltype(_::StratNodeReprPeriod) = TreePeriod

"""
    struct StratNodeReprPeriods <: AbstractTreeStructure

Type for iterating through the individual presentative periods of a [`StratNode`](@ref).
It is automatically created through the function [`repr_periods`](@ref).
"""
struct StratNodeReprPeriods <: AbstractTreeStructure
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    repr::Any
end

"""
    repr_periods(sp::StratNode{S,T,OP})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function repr_periods(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeReprPeriods(
        _strat_per(n),
        _branch(n),
        n.mult_sp,
        probability_branch(n),
        repr_periods(n.operational),
    )
end

_oper_struct(rps::StratNodeReprPeriods) = rps.repr
function strat_node_period(rps::StratNodeReprPeriods, next, state)
    return StratNodeReprPeriod(
        rps.sp,
        rps.branch,
        state,
        rps.mult_sp,
        mult_repr(next),
        rps.prob_branch,
        next,
    )
end

Base.eltype(_::StratNodeReprPeriods) = StratNodeReprPeriod

"""
    struct StratNodeReprOpscenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a representative period in A
[`TwoLevelTree`] structure supporting iteration over its time periods.
"""
struct StratNodeReprOpscenario{T,OP<:TimeStructure{T}} <:
       AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    rp::Int
    opscen::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::OP
end

_opscen(osc::StratNodeReprOpscenario) = osc.opscen
_rper(osc::StratNodeReprOpscenario) = osc.rp
_branch(osc::StratNodeReprOpscenario) = osc.branch
_strat_per(osc::StratNodeReprOpscenario) = osc.sp

probability(osc::StratNodeReprOpscenario) = osc.prob_branch * osc.prob_scen
probability_branch(osc::StratNodeReprOpscenario) = osc.prob_branch

StrategicTreeIndexable(::Type{<:StratNodeReprOpscenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprOpscenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratNodeReprOpscenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratNodeReprOpscenario}) = HasScenarioIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, osc::StratNodeReprOpscenario)
    return print(io, "sp$(osc.sp)-br$(osc.branch)-rp$(osc.rp)-sc$(osc.opscen)")
end
Base.eltype(_::StratNodeReprOpscenario) = TreePeriod

"""
    struct StratNodeReprOpscenarios <: AbstractTreeStructure

Type for iterating through the individual operational scenarios of a
[`StratNodeReprPeriod`](@ref). It is automatically created through the function
[`opscenarios`](@ref).
"""
struct StratNodeReprOpscenarios <: AbstractTreeStructure
    sp::Int
    branch::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    opscens::Any
end

function StratNodeReprOpscenarios(
    rp::StratNodeReprPeriod{T,OP},
    opscens,
) where {T,OP<:TimeStructure{T}}
    return StratNodeReprOpscenarios(
        _strat_per(rp),
        _branch(rp),
        _rper(rp),
        rp.mult_sp,
        rp.mult_rp,
        probability_branch(rp),
        opscens,
    )
end

"""
    opscenarios(sp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}})

Iterator that iterates over operational scenarios for a specific representative period of
a strategic node in the tree.
"""
function opscenarios(
    rp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    if _strat_per(rp) == 1 && _rper(rp) == 1
    end
    return StratNodeReprOpscenarios(
        _strat_per(rp),
        _branch(rp),
        _rper(rp),
        rp.mult_sp,
        rp.mult_rp,
        probability_branch(rp),
        opscenarios(rp.operational.operational),
    )
end
function opscenarios(
    rp::StratNodeReprPeriod{T,SingleReprPeriod{T,OP}},
) where {T,OP}
    if _strat_per(rp) == 1 && _rper(rp) == 1
    end
    return StratNodeOpScens(
        _strat_per(rp),
        _branch(rp),
        rp.mult_sp,
        probability_branch(rp),
        opscenarios(rp.operational.ts),
    )
end

_oper_struct(oscs::StratNodeReprOpscenarios) = oscs.opscens
function strat_node_period(oscs::StratNodeReprOpscenarios, next, state)
    return StratNodeReprOpscenario(
        oscs.sp,
        oscs.branch,
        oscs.rp,
        state,
        oscs.mult_sp,
        oscs.mult_rp,
        oscs.prob_branch,
        probability(next),
        next,
    )
end

Base.eltype(_::StratNodeReprOpscenarios) = StratNodeReprOpscenario

# All introduced subtypes require the same procedures for the iteration and indexing.
# Hence, all introduced types use the same functions.
TreeStructure = Union{
    StratNodeOperationalScenario,
    StratNodeReprPeriod,
    StratNodeReprOpscenario,
}
Base.length(ts::TreeStructure) = length(ts.operational)
function Base.last(ts::TreeStructure)
    per = last(ts.operational)
    return TreePeriod(ts, per)
end

function Base.getindex(ts::TreeStructure, index)
    per = ts.operational[index]
    return TreePeriod(ts, per)
end
function Base.eachindex(ts::TreeStructure)
    return eachindex(ts.operational)
end
function Base.iterate(ts::TreeStructure, state = nothing)
    next =
        isnothing(state) ? iterate(ts.operational) :
        iterate(ts.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(ts, next[1]), next[2]
end
