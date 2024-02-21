
"""
    AbstractRepresentativePeriod

Abstract type used for time structures that represent a representative
period.
"""
abstract type AbstractRepresentativePeriod{T} <: TimeStructure{T} end

function _rper(rp::AbstractRepresentativePeriod)
    return error("_rper() not implemented for $(typeof(rp))")
end
isfirst(rp::AbstractRepresentativePeriod) = _rper(rp) == 1

function Base.last(rp::AbstractRepresentativePeriod)
    return error(
        "last() is not supported for a representative period. If you need access
     to the last time period it should be done within each operational scenario
     of the representative period obtained with `opscenarios(rp)`",
    )
end

"""
    RepresentativePeriod

A structure representing a single representative period supporting
iteration over its time periods.
"""
struct RepresentativePeriod{T,OP<:TimeStructure{T}} <:
       AbstractRepresentativePeriod{T}
    rper::Int
    mult_rp::Float64
    operational::OP
end
Base.show(io::IO, rp::RepresentativePeriod) = print(io, "rp-$(rp.rper)")
_rper(rp::RepresentativePeriod) = rp.rper
_mult_rp(rp::RepresentativePeriod) = rp.mult_rp

# Iterate the time periods of a representative period
function Base.iterate(rp::RepresentativePeriod, state = nothing)
    next =
        isnothing(state) ? iterate(rp.operational) :
        iterate(rp.operational, state)
    next === nothing && return nothing
    mult = rp.mult_rp * multiple(next[1])
    return ReprPeriod(rp.rper, next[1], mult), next[2]
end

Base.length(rp::RepresentativePeriod) = length(rp.operational)
Base.eltype(::Type{RepresentativePeriod}) = ReprPeriod

# Iteration through representative periods
struct ReprPeriods{T,OP}
    ts::RepresentativePeriods{T,OP}
end

"""
    repr_periods(ts)

Iterator that iterates over representative periods in an `RepresentativePeriods` time structure.
"""
repr_periods(ts::RepresentativePeriods) = ReprPeriods(ts)

Base.length(rpers::ReprPeriods) = rpers.ts.len

function Base.iterate(rpers::ReprPeriods)
    return RepresentativePeriod(
        1,
        _multiple_adj(rpers.ts, 1),
        rpers.ts.rep_periods[1],
    ),
    1
end

function Base.iterate(rpers::ReprPeriods, state)
    state == rpers.ts.len && return nothing
    return RepresentativePeriod(
        state + 1,
        _multiple_adj(rpers.ts, state + 1),
        rpers.ts.rep_periods[state+1],
    ),
    state + 1
end

function Base.last(rpers::ReprPeriods)
    return RepresentativePeriod(
        rpers.ts.len,
        _multiple_adj(rpers.ts, rpers.ts.len),
        rpers.ts.rep_periods[rpers.ts.len],
    )
end

struct StratReprPeriod{T,OP<:TimeStructure{T}} <:
       AbstractRepresentativePeriod{T}
    sp::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    operational::OP
end

multiple(srp::StratReprPeriod, t::OperationalPeriod) = t.multiple / srp.mult_sp

function Base.show(io::IO, srp::StratReprPeriod)
    return print(io, "sp$(srp.sp)-rp$(srp.rp)")
end
_rper(srp::StratReprPeriod) = srp.rp
_mult_rp(srp::StratReprPeriod) = srp.mult_rp

# Iterate the time periods of a StratReprPeriod
function Base.iterate(srp::StratReprPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(srp.operational) :
        iterate(srp.operational, state)
    isnothing(next) && return nothing

    per = next[1]
    mult = srp.mult_sp * multiple(per)
    return OperationalPeriod(srp.sp, per, mult), next[2]
end

Base.length(srp::StratReprPeriod) = length(srp.operational)
function Base.eltype(::Type{StratReprPeriod{T}}) where {T}
    return OperationalPeriod
end

# Iteration through representative periods
struct StratReprPeriods
    sper::StrategicPeriod
    repr::Any
end

"""
    repr_periods(sper)

    Iterator that iterates over representative periods for a specific strategic period.
"""
function repr_periods(sper::StrategicPeriod)
    return StratReprPeriods(sper, repr_periods(sper.operational))
end

"""
    repr_periods(ts)

    Returns a collection of all representative periods for a TwoLevel time structure.
"""
function repr_periods(ts::TwoLevel)
    rps = StratReprPeriod[]
    for sp in strategic_periods(ts)
        push!(rps, repr_periods(sp)...)
    end
    return rps
end

Base.length(reps::StratReprPeriods) = length(reps.repr)

_multiple_rp(rpers, rper) = 1.0
_multiple_rp(rpers::ReprPeriods, rper) = _multiple_adj(rpers.ts, rper)

function Base.iterate(reps::StratReprPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(reps.repr) : iterate(reps.repr, state[1])
    isnothing(next) && return nothing

    rper = state[2]
    mult_sp = reps.sper.mult_sp
    mult_rp = _multiple_rp(reps.repr, rper)
    return StratReprPeriod(reps.sper.sp, rper, mult_sp, mult_rp, next[1]),
    (next[2], rper + 1)
end

function Base.last(reps::StratReprPeriods)
    per = last(reps.repr)

    return StratReprPeriod(
        reps.sper.sp,
        _rper(per),
        reps.sper.mult_sp,
        _mult_rp(per),
        per,
    )
end

struct SingleReprPeriodWrapper{T,RP<:TimeStructure{T}} <: TimeStructure{T}
    ts::RP
end

function Base.iterate(srp::SingleReprPeriodWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleReprPeriod(srp.ts), 1
end
Base.length(srp::SingleReprPeriodWrapper) = 1
function Base.eltype(::Type{SingleReprPeriodWrapper{T,RP}}) where {T,RP}
    return SingleReprPeriod{T,RP}
end
Base.last(srp::SingleReprPeriodWrapper) = SingleReprPeriod(srp.ts)

struct SingleReprPeriod{T,RP<:TimeStructure{T}} <:
       AbstractRepresentativePeriod{T}
    ts::RP
end
_rper(rp::SingleReprPeriod) = 1
_mult_rp(rp::SingleReprPeriod) = 1.0

Base.length(srp::SingleReprPeriod) = length(srp.ts)
Base.eltype(::Type{SingleReprPeriod{T,RP}}) where {T,RP} = eltype(RP)

function Base.iterate(srp::SingleReprPeriod, state = nothing)
    if isnothing(state)
        return iterate(srp.ts)
    end
    return iterate(srp.ts, state)
end

# Default solution is to behave as a single representative period
repr_periods(ts::TimeStructure) = SingleReprPeriodWrapper(ts)

# If the strategic level is a wrapped time structure, shortcut to get
# correct behaviour
repr_periods(ts::SingleStrategicPeriod) = repr_periods(ts.ts)
