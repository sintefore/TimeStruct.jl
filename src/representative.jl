"""
    struct RepresentativePeriods{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}

    RepresentativePeriods(len::Integer, duration::S, period_share::Vector{<:Real}, rep_periods::Vector{OP}) where {S<:Duration, T, OP<:TimeStructure{T}}
    RepresentativePeriods(len::Integer, duration::S, rep_periods::TimeStructure{T}) where {S<:Duration, T}

    RepresentativePeriods(duration::S, period_share::Vector{<:Real}, rep_periods::Vector{<:TimeStructure{T}}) where {S<:Duration, T}
    RepresentativePeriods(duration::S, period_share::Vector{<:Real}, rep_periods::TimeStructure{T}) where {S<:Duration, T}

    RepresentativePeriods(duration::S, rep_periods::Vector{<:TimeStructure{T}}) where {S<:Duration, T}


Time structure that allows a time period to be represented by one or more
shorter representative time periods.

The representative periods are an ordered sequence of TimeStructures that are
used for each representative period. In addition, each representative period
has an associated share that specifies how much of the total duration that
is attributed to it.

!!! note
    - All representative periods must use the same type for the `TimeStructure`.
    - If the field `period_share` is not specified, it assigns the same probability to each
      representative period.
    - It is possible that `sum(period_share)` is larger or smaller than 1. This can lead to
      problems in your application. Hence, it is advised to scale it. Currently, a warning
      will be given if the period shares do not sum to one as an automatic scaling will
      correspond to a breaking change.
    - If you include [`OperationalScenarios`](@ref) in your time structure, it is important
      that the scenarios are within the representative periods, and not the other way.

### Example
```julia
# A year represented by two days with hourly resolution and relative shares of 0.7 and 0.3
RepresentativePeriods(8760, [0.7, 0.3], [SimpleTimes(24, 1), SimpleTimes(24,1)])
RepresentativePeriods(8760, [0.7, 0.3], SimpleTimes(24, 1))

# A year represented by two days with hourly resolution and relative shares of 0.5
RepresentativePeriods(2, 8760, SimpleTimes(24, 1))
RepresentativePeriods(8760, [SimpleTimes(24, 1), SimpleTimes(24,1)])
```
"""
struct RepresentativePeriods{S<:Duration,T,OP<:TimeStructure{T}} <:
       TimeStructure{T}
    len::Int
    duration::S
    period_share::Vector{Float64}
    rep_periods::Vector{OP}
    function RepresentativePeriods(
        len::Integer,
        duration::S,
        period_share::Vector{<:Real},
        rep_periods::Vector{OP},
    ) where {S<:Duration,T,OP<:TimeStructure{T}}
        if len > length(period_share)
            throw(
                ArgumentError(
                    "The length of `period_share` cannot be less than the field `len` of `RepresentativePeriods`.",
                ),
            )
        elseif len > length(rep_periods)
            throw(
                ArgumentError(
                    "The length of `rep_periods` cannot be less than the field `len` of `RepresentativePeriods`.",
                ),
            )
        elseif sum(period_share) > 1 || sum(period_share) < 1
            @warn(
                "The sum of the `period_share` vector is given by $(sum(period_share)). " *
                "This can lead to unexpected behaviour."
            )
        end
        return new{S,T,OP}(len, duration, convert(Vector{Float64}, period_share), rep_periods)
    end
end
function RepresentativePeriods(
    len::Integer,
    duration::S,
    rep_periods::TimeStructure{T},
) where {S<:Duration,T}
    return RepresentativePeriods(
        len,
        duration,
        fill(1.0 / len, len),
        fill(rep_periods, len),
    )
end
function RepresentativePeriods(
    duration::S,
    period_share::Vector{<:Real},
    rep_periods::Vector{<:TimeStructure{T}},
) where {S<:Duration,T}
    return RepresentativePeriods(
        length(rep_periods),
        duration,
        period_share,
        rep_periods,
    )
end
function RepresentativePeriods(
    duration::S,
    period_share::Vector{<:Real},
    rep_periods::TimeStructure{T},
) where {S<:Duration,T}
    return RepresentativePeriods(
        length(period_share),
        duration,
        period_share,
        fill(rep_periods, length(period_share)),
    )
end
function RepresentativePeriods(
    duration::S,
    rep_periods::Vector{<:TimeStructure{T}},
) where {S<:Duration,T}
    return RepresentativePeriods(
        length(rep_periods),
        duration,
        fill(1.0 / length(rep_periods), length(rep_periods)),
        rep_periods,
    )
end

_total_duration(ts::RepresentativePeriods) = ts.duration

function _multiple_adj(ts::RepresentativePeriods, rper)
    mult =
        _total_duration(ts) * ts.period_share[rper] /
        _total_duration(ts.rep_periods[rper])
    return stripunit(mult)
end

# Iteration through all time periods for the representative periods
function Base.iterate(ts::RepresentativePeriods)
    rp = 1
    next = iterate(ts.rep_periods[rp])
    next === nothing && return nothing
    mult = _multiple_adj(ts, rp) * multiple(next[1])
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
    mult = _multiple_adj(ts, rp) * multiple(next[1])
    return ReprPeriod(rp, next[1], mult), (rp, next[2])
end

function Base.length(ts::RepresentativePeriods)
    return sum(length(rpers) for rpers in ts.rep_periods)
end

function Base.last(ts::RepresentativePeriods)
    per = last(ts.rep_periods[ts.len])
    mult = _multiple_adj(ts, ts.len) * multiple(per)
    return ReprPeriod(ts.len, per, mult)
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
