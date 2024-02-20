abstract type AbstractStrategicPeriod{T} <: TimeStructure{T} end

function duration_strat(sp::AbstractStrategicPeriod)
    return error("duration_strat() not implemented for $(typeof(sp))")
end
function _strat_per(sp::AbstractStrategicPeriod)
    return error("_strat_per() not implemented for $(typeof(sp))")
end

"""
    StrategicPeriod <: TimePeriod

Time period for iteration of strategic periods.
"""
struct StrategicPeriod{S,T,OP<:TimeStructure{T}} <: AbstractStrategicPeriod{T}
    sp::Int
    duration::S
    mult_sp::Float64
    operational::OP
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
Base.isless(sp1::StrategicPeriod, sp2::StrategicPeriod) = sp1.sp < sp2.sp

duration_strat(sp::StrategicPeriod) = sp.duration
_strat_per(sp::StrategicPeriod) = sp.sp

"""
    multiple_strat(sp::StrategicPeriod, t)

Returns the number of times a time period `t` should be accounted for
when accumulating over one single unit of strategic time.

# Example
```julia
periods = TwoLevel(10, 1, SimpleTimes(24,1); op_per_strat = 8760)
for sp in strategic_periods(periods)
    hours_per_year = sum(duration(t) * multiple_strat(sp, t) for t in sp)
end
```
"""
multiple_strat(sp::StrategicPeriod, t) = multiple(t) / duration(sp)

multiple(ts::TwoLevel, sp::StrategicPeriod) = _multiple_adj(ts, sp.sp)

struct StratPeriods{S,T,OP}
    ts::TwoLevel{S,T,OP}
end

"""
    strat_periods(ts::TwoLevel)

Iteration through the strategic periods of a 'TwoLevel' structure.
"""
strat_periods(ts::TwoLevel) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len

function Base.iterate(sps::StratPeriods)
    mult_sp = _multiple_adj(sps.ts, 1)
    return StrategicPeriod(
        1,
        sps.ts.duration[1],
        mult_sp,
        sps.ts.operational[1],
    ),
    1
end

function Base.iterate(sps::StratPeriods, state)
    state == sps.ts.len && return nothing
    mult_sp = _multiple_adj(sps.ts, state + 1)
    sp = StrategicPeriod(
        state + 1,
        sps.ts.duration[state+1],
        mult_sp,
        sps.ts.operational[state+1],
    )
    return sp, state + 1
end

Base.length(itr::StrategicPeriod) = length(itr.operational)
function Base.eltype(::Type{StrategicPeriod{S,T,OP}}) where {S,T,OP}
    return OperationalPeriod
end

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]

    mult = itr.mult_sp * multiple(per)
    return OperationalPeriod(itr.sp, per, mult), next[2]
end

function start_time(sp::StrategicPeriod, ts::TwoLevel{S}) where {S}
    return isfirst(sp) ? zero(S) :
           sum(duration_strat(spp) for spp in strategic_periods(ts) if spp < sp)
end

function end_time(sp::StrategicPeriod, ts::TwoLevel)
    return start_time(sp, ts) + duration_strat(sp)
end

function remaining(sp::StrategicPeriod, ts::TwoLevel)
    return sum(
        duration_strat(spp) for spp in strategic_periods(ts) if spp >= sp
    )
end

struct SingleStrategicPeriodWrapper{T,SP<:TimeStructure{T}} <: TimeStructure{T}
    ts::SP
end

function Base.iterate(ssp::SingleStrategicPeriodWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleStrategicPeriod(ssp.ts), 1
end
Base.length(ssp::SingleStrategicPeriodWrapper) = 1
function Base.eltype(::Type{SingleStrategicPeriodWrapper{T,SP}}) where {T,SP}
    return SingleStrategicPeriod{T,RP}
end

struct SingleStrategicPeriod{T,SP<:TimeStructure{T}} <:
       AbstractStrategicPeriod{T}
    ts::SP
end
Base.length(ssp::SingleStrategicPeriod) = length(ssp.ts)
Base.eltype(::Type{SingleStrategicPeriod{T,SP}}) where {T,SP} = eltype(SP)

function Base.iterate(ssp::SingleStrategicPeriod, state = nothing)
    if isnothing(state)
        return iterate(ssp.ts)
    end
    return iterate(ssp.ts, state)
end

duration_strat(ssp::SingleStrategicPeriod) = _total_duration(ts)
_strat_per(ssp::SingleStrategicPeriod) = 1

# Default solution is to behave as a single strategic period
strat_periods(ts::TimeStructure) = SingleStrategicPeriodWrapper(ts)

strategic_periods(ts) = strat_periods(ts)
