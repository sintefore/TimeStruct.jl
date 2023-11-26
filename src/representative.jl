"""
    RepresentativePeriods <: TimeStructure

Time structure that allows a time period to be represented by one or more
shorter representative time periods.

The representative periods are an ordered sequence of TimeStructures that are
used for each representative period. In addition, each representative period
has an associated share that specifies how much of the total duration that
is attributed to it.

### Example
```julia
# A year represented by two days with hourly resolution and relative shares of 0.7 and 0.3
periods = RepresentativePeriods(2, 8760, [0.7, 0.3], [SimpleTimes(24, 1), SimpleTimes(24,1)])
```
"""
struct RepresentativePeriods{S,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    duration::S
    period_share::Vector{Float64}
    rep_periods::Vector{OP}
end

duration(ts::RepresentativePeriods) = sum(ts.duration)

# Iteration through all time periods for the representative periods
function Base.iterate(ts::RepresentativePeriods)
    rp = 1
    next = iterate(ts.rep_periods[rp])
    next === nothing && return nothing
    mult_adj = stripunit(
        ts.period_share[rp] * ts.duration / duration(ts.rep_periods[rp]),
    )
    mult = mult_adj * multiple(next[1])
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
    mult_adj = stripunit(
        ts.period_share[rp] * ts.duration / duration(ts.rep_periods[rp]),
    )
    mult = mult_adj * multiple(next[1])
    return ReprPeriod(rp, next[1], mult), (rp, next[2])
end

function Base.length(ts::RepresentativePeriods)
    return sum(length(rpers) for rpers in ts.rep_periods)
end

Base.eltype(::Type{RepresentativePeriods}) = ReprPeriod

# A single operational time period used when iterating through
# a represenative period
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
multiple(t::ReprPeriod) = t.mult

_oper(t::ReprPeriod) = _oper(t.period)
_opscen(t::ReprPeriod) = _opscen(t.period)
_rper(t::ReprPeriod) = t.rp

"""
    RepresentativePeriod

A structure representing a single representative period supporting
iteration over its time periods.
"""
struct RepresentativePeriod{S,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    rper::Int
    operational::OP
    duration::S
    per_share::Float64
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
    mult_adj = stripunit(rp.per_share * rp.duration / duration(rp.operational))
    mult = mult_adj * multiple(next[1])
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
        rpers.ts.rep_periods[1],
        rpers.ts.duration[1],
        rpers.ts.period_share[1],
    ),
    1
end

function Base.iterate(rpers::ReprPeriods, state)
    state == rpers.ts.len && return nothing
    return RepresentativePeriod(
        state + 1,
        rpers.ts.rep_periods[state+1],
        rpers.ts.duration,
        rpers.ts.period_share[state+1],
    ),
    state + 1
end

# Fallback solution is to behave as a single representative period
repr_periods(ts::TimeStructure) = [ts]
