"""
    AbstractTreeNode{T} <: TimeStructure{T}

Abstract base type for all tree nodes within a [`TwoLevelTree`] type
"""
abstract type AbstractTreeNode{T} <: TimeStructure{T} end

struct StratNode{S, T, OP<:TimeStructure{T}} <: AbstractTreeNode{T}
    sp::Int
    branch::Int
    duration::S
    prob_branch::Float64
    mult_sp::Float64
    parent::Any
    operational::OP
end

Base.show(io::IO, n::StratNode) = print(io, "sp$(n.sp)-br$(n.branch)")
_branch(n::StratNode) = n.branch
_strat_per(n::StratNode) = n.sp
probability_branch(n::StratNode) = n.prob_branch
duration_strat(n::StratNode) = n.duration
multiple_strat(sp::StratNode, t) = multiple(t) / duration_strat(sp)

isfirst(n::StratNode) = n.sp == 1

# Iterate through time periods of a strategic node
Base.length(n::StratNode) = length(n.operational)
Base.eltype(::Type{StratNode{T}}) where {T} = TreePeriod
function Base.iterate(itr::StratNode, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]

    mult = itr.mult_sp * multiple(per)
    return TreePeriod(itr.sp, itr.branch, probability_branch(itr), mult, per),
    next[2]
end

abstract type StrategicTreeIndexable end

struct HasStratTreeIndex <: StrategicTreeIndexable end
struct NoStratTreeIndex <: StrategicTreeIndexable end

StrategicTreeIndexable(::Type) = NoStratTreeIndex()
StrategicTreeIndexable(::Type{<:AbstractTreeNode}) = HasStratTreeIndex()
StrategicTreeIndexable(::Type{<:TimePeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:AbstractTreeNode}) = HasStratIndex()


"""
    struct StratNodeOperationalScenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a strategic node supporting
iteration over its time periods.
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

function Base.show(io::IO, os::StratNodeOperationalScenario)
    return print(io, "sp$(os.sp)-br$(os.branch)-sc$(os.scen)")
end

probability(os::StratNodeOperationalScenario) = os.prob_branch * prob_scen
mult_scen(os::StratNodeOperationalScenario) = os.mult_scen
_opscen(os::StratNodeOperationalScenario) = os.scen
_branch(os::StratNodeOperationalScenario) = os.branch
_strat_per(os::StratNodeOperationalScenario) = os.sp

StrategicTreeIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratIndex()

Base.length(snops::StratNodeOperationalScenario) = length(snops.operational)
Base.eltype(_::StratNodeOperationalScenario) = TreePeriod

function Base.last(os::StratNodeOperationalScenario)
    per = last(os.operational)
    return OperationalPeriod(os.sp, per, os.mult_sp * multiple(per))
end

function Base.getindex(os::StratNodeOperationalScenario, index)
    per = os.operational[index]
    mult = os.mult_sp * multiple(per)
    return TreePeriod(os.sp, os.branch, probability_branch(os), mult, per)
end

function Base.eachindex(os::StratNodeOperationalScenario)
    return eachindex(os.operational)
end

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(os::StratNodeOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(os.sp, os.branch, os.prob_branch, os.mult_sp * multiple(next[1]), next[1]),
    next[2]
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

Base.length(ops::StratNodeOpScens) = length(ops.opscens)
Base.eltype(_::StratNodeOpScens) = StratNodeOperationalScenario

"""
    opscenarios(sp::StratNode{S,T,OP})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function opscenarios(sn::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(sn, opscenarios(sn.operational))
end

function Base.iterate(ops::StratNodeOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.opscens) :
        iterate(ops.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeOperationalScenario(
        ops.sp,
        ops.branch,
        scen,
        ops.mult_sp,
        mult_scen(next[1]),
        ops.prob_branch,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end


"""
    struct StratNodeReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A structure representing a single representative period of a strategic node supporting
iteration over its time periods.
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

function Base.show(io::IO, srp::StratNodeReprPeriod)
    return print(io, "sp$(srp.sp)-br$(srp.branch)-sc$(srp.rp)")
end

probability(srp::StratNodeReprPeriod) = srp.prob_branch
probability_branch(srp::StratNodeReprPeriod) = srp.prob_branch
multiple(srp::StratNodeReprPeriod, t::OperationalPeriod) = t.multiple / srp.mult_sp
_rper(srp::StratNodeReprPeriod) = srp.rp
_branch(srp::StratNodeReprPeriod) = srp.branch
_strat_per(srp::StratNodeReprPeriod) = srp.sp

StrategicTreeIndexable(::Type{<:StratNodeReprPeriod}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprPeriod}) = HasStratIndex()

Base.length(snrp::StratNodeReprPeriod) = length(snrp.operational)
Base.eltype(_::StratNodeReprPeriod) = TreePeriod

function Base.last(srp::StratNodeReprPeriod)
    per = last(srp.operational)
    return OperationalPeriod(srp.sp, per, srp.mult_sp * multiple(per))
end

function Base.getindex(srp::StratNodeReprPeriod, index)
    per = srp.operational[index]
    mult = srp.mult_sp * multiple(per)
    return TreePeriod(srp.sp, srp.branch, probability_branch(srp), mult, per)
end

function Base.eachindex(srp::StratNodeReprPeriod)
    return eachindex(srp.operational)
end

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(srp::StratNodeReprPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(srp.operational) :
        iterate(srp.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(srp.sp, srp.branch, srp.prob_branch, srp.mult_sp * multiple(next[1]), next[1]),
    next[2]
end

"""
    struct StratNodeReprPeriods

Type for iterating through the individual operational scenarios of a [`StratNode`](@ref).
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

Base.length(ops::StratNodeReprPeriods) = length(ops.repr)
Base.eltype(_::StratNodeReprPeriods) = StratNodeReprPeriod

"""
    repr_periods(sp::StratNode{S,T,OP})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function repr_periods(sn::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeReprPeriods(sn, repr_periods(sn.operational))
end

function Base.iterate(ops::StratNodeReprPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.repr) :
        iterate(ops.repr, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeReprPeriod(
        ops.sp,
        ops.branch,
        scen,
        ops.mult_sp,
        mult_repr(next[1]),
        ops.prob_branch,
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

probability(os::StratNodeReprOpscenario) = os.prob_branch * os.prob_scen
probability_branch(os::StratNodeReprOpscenario) = os.prob_branch
_opscen(os::StratNodeReprOpscenario) = os.opscen
_rper(os::StratNodeReprOpscenario) = os.rp
_branch(os::StratNodeReprOpscenario) = os.branch
_strat_per(os::StratNodeReprOpscenario) = os.sp

function Base.show(io::IO, srop::StratNodeReprOpscenario)
    return print(io, "sp$(srop.sp)-br$(os.branch)-rp$(srop.rp)-sc$(srop.opscen)")
end

StrategicTreeIndexable(::Type{<:StratNodeReprOpscenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprOpscenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratNodeReprOpscenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratNodeReprOpscenario}) = HasScenarioIndex()

function Base.last(os::StratNodeReprOpscenario)
    per = last(os.operational)
    rper = ReprPeriod(os.rp, per, os.mult_rp * multiple(per))
    return TreePeriod(
        os.sp,
        os.branch,
        probability_branch(os),
        os.mult_sp * os.mult_rp * multiple(per),
        rper,
    )
end

function Base.getindex(os::StratNodeReprOpscenario, index)
    mult = stripunit(os.duration * os.op_per_strat / duration(os.operational))
    period = ReprPeriod(os.rp, os.operational[index], mult)
    return TreePeriod(os.sp, os.branch, probability_branch(os), mult, period)
end

function Base.eachindex(os::StratNodeReprOpscenario)
    return eachindex(os.operational)
end

# Iterate the time periods of a StratNodeReprOpscenario
function Base.iterate(os::StratNodeReprOpscenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    period = ReprPeriod(os.rp, next[1], os.mult_rp * multiple(next[1]))
    return TreePeriod(
        os.sp,
        os.branch,
        probability_branch(os),
        os.mult_sp * os.mult_rp * multiple(next[1]),
        period,
    ),
    next[2]
end

Base.length(os::StratNodeReprOpscenario) = length(os.operational)

function Base.eltype(::Type{StratNodeReprOpscenario{T}}) where {T}
    return TreePeriod
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

function StratNodeReprOpscenarios(n::StratNodeReprPeriod{T,OP}, opscens) where {T,OP<:TimeStructure{T}}
    return StratNodeReprOpscenarios(_strat_per(n), _branch(n), _rper(n), n.mult_sp, n.mult_rp, probability_branch(n), opscens)
end

"""
    opscenarios(sp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}})

Iterator that iterates over operational scenarios for a specific strategic node in the tree.
"""
function opscenarios(
    srp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    return StratNodeReprOpscenarios(srp, opscenarios(srp.operational.operational))
end

Base.length(srop::StratNodeReprOpscenarios) = length(srop.opscens)

function Base.iterate(srop::StratNodeReprOpscenarios, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(srop.opscens) :
        iterate(srop.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratNodeReprOpscenario(
        srop.sp,
        srop.branch,
        srop.rp,
        scen,
        srop.mult_sp,
        srop.mult_rp,
        srop.prob_branch,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end
