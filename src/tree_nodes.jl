"""
    AbstractTreeNode{T} <: TimeStructure{T}

Abstract base type for all tree nodes within a [`TwoLevelTree`](@ref) type.
"""
abstract type AbstractTreeNode{T} <: TimeStructure{T} end

abstract type StrategicTreeIndexable end
struct HasStratTreeIndex <: StrategicTreeIndexable end
struct NoStratTreeIndex <: StrategicTreeIndexable end

StrategicTreeIndexable(::Type) = NoStratTreeIndex()
StrategicTreeIndexable(::Type{<:AbstractTreeNode}) = HasStratTreeIndex()
StrategicTreeIndexable(::Type{<:TimePeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:AbstractTreeNode}) = HasStratIndex()

"""
    struct StratNode{S, T, OP<:TimeStructure{T}} <: AbstractTreeNode{T}

A structure representing a single strategic node of a [`TwolevelTree`](@ref). It is created
through iterating through [`StratTreeNodes`](@ref).

It is equivalent to a [`StrategicPeriod`](@ref) of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwolevelTree`](@ref).
"""
struct StratNode{S, T, OP<:TimeStructure{T}} <: AbstractTreeNode{T}
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
    struct StratNodeOperationalScenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a strategic node supporting
iteration over its time periods. It is created through iterating through
[`StratNodeOpScens`](@ref).

It is equivalent to a [`StratOperationalScenario`](@ref) of a [`TwoLevel`](@ref) time
structure when utilizing a [`TwolevelTree`](@ref).
"""
struct StratNodeOperationalScenario{T} <: AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::TimeStructure{T}
end

_opscen(osc::StratNodeOperationalScenario) = osc.scen
_branch(osc::StratNodeOperationalScenario) = osc.branch
_strat_per(osc::StratNodeOperationalScenario) = osc.sp

probability(osc::StratNodeOperationalScenario) = osc.prob_branch * prob_scen
probability_branch(osc::StratNodeOperationalScenario) = osc.prob_branch
mult_scen(osc::StratNodeOperationalScenario) = osc.mult_scen

StrategicTreeIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, osc::StratNodeOperationalScenario)
    return print(io, "sp$(osc.sp)-br$(osc.branch)-sc$(osc.scen)")
end
Base.length(osc::StratNodeOperationalScenario) = length(osc.operational)
Base.eltype(_::StratNodeOperationalScenario) = TreePeriod
function Base.last(osc::StratNodeOperationalScenario)
    per = last(osc.operational)
    return TreePeriod(osc, per)
end
function Base.getindex(osc::StratNodeOperationalScenario, index)
    per = osc.operational[index]
    return TreePeriod(osc, per)
end
function Base.eachindex(osc::StratNodeOperationalScenario)
    return eachindex(osc.operational)
end
function Base.iterate(osc::StratNodeOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(osc.operational) :
        iterate(osc.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(osc, next[1]), next[2]
end

"""
    struct StratNodeOpScens

Type for iterating through the individual operational scenarios of a [`StratNode`](@ref).
It is automatically created through the function [`opscenarios`](@ref).
"""
struct StratNodeOpScens
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    opscens::Any
end

function StratNodeOpScens(n::StratNode{S,T,OP}, opscens) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(_strat_per(n), _branch(n), n.mult_sp, probability_branch(n), opscens)
end

"""
    opscenarios(sp::StratNode{S,T,OP})

When the `TimeStructure` is a [`StratNode`](@ref), `opscenarios` returns a
[`StratNodeOpScens`](@ref) used for iterating through the individual operational scenarios
"""
function opscenarios(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(n, opscenarios(n.operational))
end

Base.length(oscs::StratNodeOpScens) = length(oscs.opscens)
Base.eltype(_::StratNodeOpScens) = StratNodeOperationalScenario
function Base.iterate(oscs::StratNodeOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(oscs.opscens) :
        iterate(oscs.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeOperationalScenario(
        oscs.sp,
        oscs.branch,
        scen,
        oscs.mult_sp,
        mult_scen(next[1]),
        oscs.prob_branch,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end


"""
    struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A structure representing a single representative period of a [`StrategicNode`](@ref) of a
[`TwolevelTree`](@ref). It is created through iterating through [`StratNodeReprPeriods`](@ref).

It is equivalent to a [`StratReprPeriod`](@ref) of a [`TwoLevel`](@ref) time structure when
utilizing a [`TwolevelTree`](@ref).
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


_rper(rp::StratNodeReprPeriod) = rp.rp
_branch(rp::StratNodeReprPeriod) = rp.branch
_strat_per(rp::StratNodeReprPeriod) = rp.sp

probability(rp::StratNodeReprPeriod) = rp.prob_branch
probability_branch(rp::StratNodeReprPeriod) = rp.prob_branch
multiple(rp::StratNodeReprPeriod, t::OperationalPeriod) = t.multiple / rp.mult_sp

StrategicTreeIndexable(::Type{<:StratNodeReprPeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprPeriod}) = HasStratIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, rp::StratNodeReprPeriod)
    return print(io, "sp$(rp.sp)-br$(rp.branch)-sc$(rp.rp)")
end
Base.length(snrp::StratNodeReprPeriod) = length(snrp.operational)
Base.eltype(_::StratNodeReprPeriod) = TreePeriod
function Base.last(rp::StratNodeReprPeriod)
    per = last(rp.operational)
    return TreePeriod(rp, per)
end
function Base.getindex(rp::StratNodeReprPeriod, index)
    per = rp.operational[index]
    return TreePeriod(rp, per)
end
function Base.eachindex(rp::StratNodeReprPeriod)
    return eachindex(rp.operational)
end
function Base.iterate(rp::StratNodeReprPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(rp.operational) :
        iterate(rp.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(rp, next[1]), next[2]
end

"""
    struct StratNodeReprPeriods

Type for iterating through the individual presentative periods of a [`StratNode`](@ref).
It is automatically created through the function [`repr_periods`](@ref).
"""
struct StratNodeReprPeriods
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    repr::Any
end

function StratNodeReprPeriods(n::StratNode{S,T,OP}, repr) where {S,T,OP<:TimeStructure{T}}
    return StratNodeReprPeriods(_strat_per(n), _branch(n), n.mult_sp, probability_branch(n), repr)
end

"""
    repr_periods(sp::StratNode{S,T,OP})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function repr_periods(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeReprPeriods(n, repr_periods(n.operational))
end

Base.length(rps::StratNodeReprPeriods) = length(rps.repr)
Base.eltype(_::StratNodeReprPeriods) = StratNodeReprPeriod
function Base.iterate(rps::StratNodeReprPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(rps.repr) :
        iterate(rps.repr, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeReprPeriod(
        rps.sp,
        rps.branch,
        scen,
        rps.mult_sp,
        mult_repr(next[1]),
        rps.prob_branch,
        next[1],
    ),
    (next[2], scen + 1)
end

"""
    struct StratNodeReprOpscenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a representative period in A
[`TwoLevelTree`](@ref) structure supporting iteration over its time periods.
"""
struct StratNodeReprOpscenario{T} <: AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    rp::Int
    opscen::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::TimeStructure{T}
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
Base.length(osc::StratNodeReprOpscenario) = length(osc.operational)
Base.eltype(_::StratNodeReprOpscenario) = TreePeriod
function Base.last(osc::StratNodeReprOpscenario)
    per = last(osc.operational)
    return TreePeriod(osc, per)
end

function Base.getindex(osc::StratNodeReprOpscenario, index)
    per = osc.operational[index]
    return TreePeriod(osc, per)
end

function Base.eachindex(osc::StratNodeReprOpscenario)
    return eachindex(osc.operational)
end

# Iterate the time periods of a StratNodeReprOpscenario
function Base.iterate(osc::StratNodeReprOpscenario, state = nothing)
    next =
        isnothing(state) ? iterate(osc.operational) :
        iterate(osc.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(osc, next[1]), next[2]
end

"""
    struct StratNodeReprOpscenarios

Type for iterating through the individual operational scenarios of a
[`StratNodeReprPeriod`](@ref). It is automatically created through the function
[`opscenarios`](@ref).
"""
struct StratNodeReprOpscenarios
    sp::Int
    branch::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    opscens::Any
end

function StratNodeReprOpscenarios(rp::StratNodeReprPeriod{T,OP}, opscens) where {T,OP<:TimeStructure{T}}
    return StratNodeReprOpscenarios(_strat_per(rp), _branch(rp), _rper(rp), rp.mult_sp, rp.mult_rp, probability_branch(rp), opscens)
end

"""
    opscenarios(sp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function opscenarios(
    rp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    return StratNodeReprOpscenarios(rp, opscenarios(rp.operational.operational))
end

Base.length(oscs::StratNodeReprOpscenarios) = length(oscs.opscens)
Base.eltype(_::StratNodeReprOpscenarios) = StratNodeReprOpscenario
function Base.iterate(oscs::StratNodeReprOpscenarios, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(oscs.opscens) :
        iterate(oscs.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeReprOpscenario(
        oscs.sp,
        oscs.branch,
        oscs.rp,
        scen,
        oscs.mult_sp,
        oscs.mult_rp,
        oscs.prob_branch,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end
