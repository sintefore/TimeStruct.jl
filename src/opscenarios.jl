abstract type AbstractOperationalScenario{T} <: TimeStructure{T} end

function probability(scen::AbstractOperationalScenario)
    return error("probabilty not implemented for type $(typeof(scen))")
end

function _opscen(scen::AbstractOperationalScenario)
    return error("_opscen() not implemented for type $(typeof(scen))")
end

mult_scen(scen::AbstractOperationalScenario) = 1.0

abstract type ScenarioIndexable end

struct HasScenarioIndex <: ScenarioIndexable end
struct NoScenarioIndex <: ScenarioIndexable end

ScenarioIndexable(::Type) = NoScenarioIndex()
ScenarioIndexable(::Type{<:AbstractOperationalScenario}) = HasScenarioIndex()
ScenarioIndexable(::Type{<:TimePeriod}) = HasScenarioIndex()

"""
    struct OperationalScenario
A structure representing a single operational scenario supporting
iteration over its time periods.
"""
struct OperationalScenario{T,OP<:TimeStructure{T}} <:
       AbstractOperationalScenario{T}
    scen::Int
    probability::Float64
    mult_sc::Float64
    operational::OP
end
Base.show(io::IO, os::OperationalScenario) = print(io, "sc-$(os.scen)")
probability(os::OperationalScenario) = os.probability
mult_scen(os::OperationalScenario) = os.mult_sc
_opscen(os::OperationalScenario) = os.scen

# Iterate the time periods of an operational scenario
function Base.iterate(os::OperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    next === nothing && return nothing
    return ScenarioPeriod(
        os.scen,
        os.probability,
        os.mult_sc * multiple(next[1]),
        next[1],
    ),
    next[2]
end

Base.length(os::OperationalScenario) = length(os.operational)
Base.eltype(::Type{OperationalScenario}) = ScenarioPeriod

function Base.last(sc::OperationalScenario)
    return ScenarioPeriod(
        sc.scen,
        sc.probability,
        sc.mult_sc,
        last(sc.operational),
    )
end

function Base.getindex(os::OperationalScenario, index)
    return ScenarioPeriod(
        os.scen,
        os.probability,
        os.multiple,
        os.operational[index],
    )
end

function Base.eachindex(os::OperationalScenario)
    return eachindex(os.operational)
end

# Iteration through scenarios
struct OpScens{T}
    ts::OperationalScenarios{T}
end

#duration(os::OpScens) = duration(os.ts)

"""
    opscenarios(ts)
Iterator that iterates over operational scenarios in an `OperationalScenarios` time structure.
"""
opscenarios(ts::OperationalScenarios) = OpScens(ts)

Base.length(ops::OpScens) = ops.ts.len

function Base.iterate(ops::OpScens)
    mult_sc = _multiple_adj(ops.ts, 1)
    return OperationalScenario(
        1,
        ops.ts.probability[1],
        mult_sc,
        ops.ts.scenarios[1],
    ),
    1
end

function Base.iterate(ops::OpScens, state)
    state == ops.ts.len && return nothing
    mult_sc = _multiple_adj(ops.ts, state + 1)
    return OperationalScenario(
        state + 1,
        ops.ts.probability[state+1],
        mult_sc,
        ops.ts.scenarios[state+1],
    ),
    state + 1
end

struct ReprOperationalScenario{T,OP<:TimeStructure{T}} <:
       AbstractOperationalScenario{T}
    rper::Int
    scen::Int
    probability::Float64
    multiple_repr::Float64
    multiple_scen::Float64
    operational::OP
end

probability(ros::ReprOperationalScenario) = ros.probability
mult_scen(ros::ReprOperationalScenario) = ros.multiple_scen
_opscen(ros::ReprOperationalScenario) = ros.scen

_rper(ros::ReprOperationalScenario) = ros.rper
RepresentativeIndexable(::Type{<:ReprOperationalScenario}) = HasReprIndex()

function Base.show(io::IO, ros::ReprOperationalScenario)
    return print(io, "rp$(ros.rper)-sc$(ros.scen)")
end

# Iterate the time periods of an operational scenario
function Base.iterate(ros::ReprOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(ros.operational) :
        iterate(ros.operational, state)
    next === nothing && return nothing
    period = next[1]
    return ReprPeriod(
        ros.rper,
        ScenarioPeriod(
            ros.scen,
            ros.probability,
            ros.multiple_scen * multiple(period),
            period,
        ),
        ros.multiple_repr * ros.multiple_scen * multiple(period),
    ),
    next[2]
end
Base.length(ros::ReprOperationalScenario) = length(ros.operational)
Base.eltype(ros::ReprOperationalScenario) = ReprPeriod
function Base.last(ros::ReprOperationalScenario)
    period = last(ros.operational)
    return ReprPeriod(
        ros.rper,
        ScenarioPeriod(
            ros.scen,
            ros.probability,
            ros.multiple_scen * multiple(period),
            period,
        ),
        ros.multiple_repr * ros.multiple_scen * multiple(period),
    )
end

# Iteration through scenarios of a representative period
struct RepOpScens{T}
    rper::Int
    mult::Float64
    op_scens::OperationalScenarios{T}
end

"""
    opscenarios(rep::RepresentativePeriod)

Iterator that iterates over operational scenarios in a `RepresentativePeriod` time structure.
"""
function opscenarios(
    rep::RepresentativePeriod{T,OperationalScenarios{T,OP}},
) where {T,OP}
    return RepOpScens(rep.rper, rep.mult_rp, rep.operational)
end

Base.length(ros::RepOpScens) = length(ros.op_scens)

function Base.iterate(ros::RepOpScens)
    mult_scen = _multiple_adj(ros.op_scens, 1)
    return ReprOperationalScenario(
        ros.rper,
        1,
        ros.op_scens.probability[1],
        ros.mult,
        mult_scen,
        ros.op_scens.scenarios[1],
    ),
    1
end

function Base.iterate(ros::RepOpScens, state)
    state == length(ros.op_scens.scenarios) && return nothing
    mult_scen = _multiple_adj(ros.op_scens, state + 1)
    return ReprOperationalScenario(
        ros.rper,
        state + 1,
        ros.op_scens.probability[state+1],
        ros.mult,
        mult_scen,
        ros.op_scens.scenarios[state+1],
    ),
    state + 1
end

function opscenarios(ts::RepresentativePeriods)
    opscens = []
    for rp in repr_periods(ts)
        push!(opscens, opscenarios(rp)...)
    end
    return opscens
end

"""
    struct StratOperationalScenario

A structure representing a single operational scenario for a strategic period supporting
iteration over its time periods.
"""
struct StratOperationalScenario{T} <: AbstractOperationalScenario{T}
    sp::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    probability::Float64
    operational::TimeStructure{T}
end

function Base.show(io::IO, os::StratOperationalScenario)
    return print(io, "sp$(os.sp)-sc$(os.scen)")
end
probability(os::StratOperationalScenario) = os.probability
mult_scen(os::StratOperationalScenario) = os.mult_scen
_opscen(os::StratOperationalScenario) = os.scen
_strat_per(os::StratOperationalScenario) = os.sp

StrategicIndexable(::Type{<:StratOperationalScenario}) = HasStratIndex()
ScenarioIndexable(::Type{<:StratOperationalScenario}) = HasScenarioIndex()

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(os::StratOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(os.sp, next[1], os.mult_sp * multiple(next[1])),
    next[2]
end

Base.length(os::StratOperationalScenario) = length(os.operational)

function Base.eltype(::Type{StratOperationalScenario{T}}) where {T}
    return OperationalPeriod
end

function Base.last(os::StratOperationalScenario)
    per = last(os.operational)
    return OperationalPeriod(os.sp, per, os.mult_sp * multiple(per))
end

function Base.getindex(os::StratOperationalScenario, index)
    per = os.operational[index]
    return OperationalPeriod(os.sp, per, os.mult_sp * multiple(per))
end

function Base.eachindex(os::StratOperationalScenario)
    return eachindex(os.operational)
end

# Iteration through scenarios
struct StratOpScens
    sp::Int
    mult_sp::Float64
    opscens::Any
end

function StratOpScens(sper::StrategicPeriod, opscens)
    return StratOpScens(sper.sp, sper.mult_sp, opscens)
end

"""
    opscenarios(sp::StrategicPeriod)

    Iterator that iterates over operational scenarios for a specific strategic period.
"""
function opscenarios(sper::StrategicPeriod{S,T,OP}) where {S,T,OP}
    return StratOpScens(sper, opscenarios(sper.operational))
end

function opscenarios(
    sp::StrategicPeriod{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    opscens = StratReprOpscenario[]
    for rp in repr_periods(sp)
        push!(opscens, opscenarios(rp)...)
    end
    return opscens
end

"""
    opscenarios(ts::TwoLevel)

    Returns a collection of all operational scenarios for a TwoLevel time structure.
"""
function opscenarios(ts::TwoLevel{S,T,OP}) where {S,T,OP}
    opscens = StratOperationalScenario[]
    for sp in strategic_periods(ts)
        push!(opscens, opscenarios(sp)...)
    end
    return opscens
end

function opscenarios(
    ts::TwoLevel{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    opscens = StratReprOpscenario[]
    for sp in strategic_periods(ts)
        for rp in repr_periods(sp)
            push!(opscens, opscenarios(rp)...)
        end
    end
    return opscens
end

Base.length(ops::StratOpScens) = length(ops.opscens)

function Base.iterate(ops::StratOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.opscens) :
        iterate(ops.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratOperationalScenario(
        ops.sp,
        scen,
        ops.mult_sp,
        mult_scen(next[1]),
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end

struct StratReprOpscenario{T} <: AbstractOperationalScenario{T}
    sp::Int
    rp::Int
    opscen::Int
    mult_sp::Float64
    mult_rp::Float64
    probability::Float64
    operational::TimeStructure{T}
end

probability(sro::StratReprOpscenario) = sro.probability
_opscen(sro::StratReprOpscenario) = sro.opscen
_strat_per(sro::StratReprOpscenario) = sro.sp
_rper(sro::StratReprOpscenario) = sro.rp

function Base.show(io::IO, srop::StratReprOpscenario)
    return print(io, "sp$(srop.sp)-rp$(srop.rp)-sc$(srop.opscen)")
end

StrategicIndexable(::Type{<:StratReprOpscenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratReprOpscenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratReprOpscenario}) = HasScenarioIndex()

# Iterate the time periods of a StratReprOpscenario
function Base.iterate(os::StratReprOpscenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    period = ReprPeriod(os.rp, next[1], os.mult_rp * multiple(next[1]))
    return OperationalPeriod(
        os.sp,
        period,
        os.mult_sp * os.mult_rp * multiple(next[1]),
    ),
    next[2]
end

Base.length(os::StratReprOpscenario) = length(os.operational)

function Base.eltype(::Type{StratReprOpscenario{T}}) where {T}
    return OperationalPeriod
end

function Base.last(sro::StratReprOpscenario)
    per = last(sro.operational)
    rper = ReprPeriod(sro.rp, per, sro.mult_rp * multiple(per))
    return OperationalPeriod(
        sro.sp,
        rper,
        sro.mult_sp * sro.mult_rp * multiple(per),
    )
end

function Base.getindex(os::StratReprOpscenario, index)
    mult = stripunit(os.duration * os.op_per_strat / duration(os.operational))
    period = ReprPeriod(os.rp, os.operational[index], mult)
    return OperationalPeriod(os.sp, period, mult)
end

function Base.eachindex(os::StratReprOpscenario)
    return eachindex(os.operational)
end

struct StratReprOpscenarios
    srp::StratReprPeriod
    opscens::Any
end

function opscenarios(
    srp::StratReprPeriod{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    return StratReprOpscenarios(srp, opscenarios(srp.operational.operational))
end

function opscenarios(srp::StratReprPeriod)
    return StratOpScens(srp.sp, srp.mult_sp, opscenarios(srp.operational))
end

Base.length(srop::StratReprOpscenarios) = length(srop.opscens)

function Base.iterate(srop::StratReprOpscenarios, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(srop.opscens) :
        iterate(srop.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratReprOpscenario(
        srop.srp.sp,
        srop.srp.rp,
        scen,
        srop.srp.mult_sp,
        srop.srp.mult_rp,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end

struct SingleScenarioWrapper{T,SC<:TimeStructure{T}} <: TimeStructure{T}
    ts::SC
end

function Base.iterate(ssw::SingleScenarioWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleScenario(ssw.ts), 1
end
Base.length(ssw::SingleScenarioWrapper) = 1
function Base.eltype(::Type{SingleScenarioWrapper{T,SC}}) where {T,SC}
    return SingleScenario{T,SC}
end

struct SingleScenario{T,SC<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    ts::SC
end
Base.length(ss::SingleScenario) = length(ss.ts)
Base.eltype(::Type{SingleScenario{T,SC}}) where {T,SC} = eltype(SC)

function Base.iterate(ss::SingleScenario, state = nothing)
    if isnothing(state)
        return iterate(ss.ts)
    end
    return iterate(ss.ts, state)
end
Base.last(ss::SingleScenario) = last(ss.ts)
function Base.last(
    ss::SingleScenario{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    period = last(ss.ts.operational)
    return ReprPeriod(ss.ts.rper, period, ss.ts.mult_rp * multiple(period))
end

function Base.getindex(ss::SingleScenario, index)
    return ss.ts[index]
end

function Base.eachindex(ss::SingleScenario)
    return eachindex(ss.ts)
end

probability(ss::SingleScenario) = 1.0
_strat_per(ss::SingleScenario) = 1
_repr_per(ss::SingleScenario) = 1
_opscen(ss::SingleScenario) = 1

StrategicIndexable(::Type{<:SingleScenario}) = HasStratIndex()
RepresentativeIndexable(::Type{<:SingleScenario}) = HasRepresentativeIndex()
ScenarioIndexable(::Type{<:SingleScenario}) = HasScenarioIndex()

# Allow TimeStructures without operational scenarios to behave as one operational scenario
opscenarios(ts::TimeStructure) = SingleScenarioWrapper(ts)

opscenarios(ts::SingleReprPeriod) = opscenarios(ts.ts)
opscenarios(ts::SingleStrategicPeriod) = opscenarios(ts.ts)
