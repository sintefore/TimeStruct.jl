struct RepresentativePeriods{S,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    rep_periods::Vector{OP}
end

duration(ts::RepresentativePeriods) = sum(ts.duration)

# Iteration through all time periods for the representative
function Base.iterate(ts::RepresentativePeriods)
    rp = 1
    next = iterate(ts.rep_periods[rp])
    next === nothing && return nothing
    mult = ts.duration[rp] / total_duration(next[1])
    return ReprPeriod(rp, next[1], mult), (rp, next[2])
end

function Base.iterate(ts::RepresentativePeriods, state)
    rp = state[1]
    next = iterate(ts.rep_periods[rp], state[2])
    if next === nothing
        rp = rp + 1
        if rp > ts.len
            return nothing
        end
        next = iterate(ts.rep_periods[rp])
    end
    mult = ts.duration[rp] / total_duration(next[1])
    return ReprPeriod(rp, next[1], mult), (rp, next[2])
end

function Base.length(ts::RepresentativePeriods)
    return sum(length(rpers) for rpers in ts.rep_periods)
end

Base.eltype(::Type{RepresentativePeriods}) = ReprPeriod

struct ReprPeriod{T} <: TimePeriod 
    rp::Int
    period::T
    mult::Float64
end

Base.show(io::IO, rp::ReprPeriod) = print(io, "rp$(rp.rp)-$(rp.period)")
function Base.isless(t1::ReprPeriod, t2::ReprPeriod)
    return t1.rp < t2.rp || (t1.rp == t2.rp && t1.period < t2.period)
end

isfirst(t::ReprPeriod) = isfirst(t.period)
duration(t::ReprPeriod) = duration(t.period)
probability(t::ReprPeriod) = probability(t.period)

_oper(t::ReprPeriod) = _oper(t.period)
_opscen(t::ReprPeriod) = _opscen(t.period)
_rper(t::ReprPeriod) = t.rp

"""
    struct RepresentativePeriod 
A structure representing a single representative period supporting
iteration over its time periods.
"""
struct RepresentativePeriod{T} <: TimeStructure{T}
    rper::Int
    operational::TimeStructure{T}
    duration::T
end
Base.show(io::IO, rp::RepresentativePeriod) = print(io, "rp-$(rp.rper)")
probability(rp::RepresentativePeriod) = 1.0
duration(rp::RepresentativePeriod) = rp.duration

# Iterate the time periods of a representative period
function Base.iterate(rp::RepresentativePeriod, state = nothing)
    next =
        isnothing(state) ? iterate(rp.operational) :
        iterate(rp.operational, state)
    next === nothing && return nothing
    mult = rp.duration / total_duration(next[1])
    return ReprPeriod(rp.rper, next[1], mult), next[2]
end

Base.length(rp::RepresentativePeriod) = length(rp.operational)
Base.eltype(::Type{RepresentativePeriod}) = ReprPeriod

# Iteration through representative periods 
struct ReprPeriods{T, OP}
    ts::RepresentativePeriods{T, OP}
end

"""
    repr_periods(ts)
Iterator that iterates over representative periods in an `RepresentativePeriods` time structure.
"""
repr_periods(ts) = ReprPeriods(ts)

Base.length(rpers::ReprPeriods) = rpers.ts.len

function Base.iterate(rpers::ReprPeriods)
    return RepresentativePeriod(1,  rpers.ts.rep_periods[1], rpers.ts.duration[1]), 1
end

function Base.iterate(rpers::ReprPeriods, state)
    state == rpers.ts.len && return nothing
    return RepresentativePeriod(
        state + 1,
        rpers.ts.rep_periods[state+1],
        rpers.ts.duration[state+1],
    ),
    state + 1
end

