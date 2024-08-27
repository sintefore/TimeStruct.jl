"""
    struct TwoLevel{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}

    TwoLevel(len::Integer, duration::Vector{S}, operational::Vector{OP}, op_per_strat::Float64) where {S<:Number, T, OP<:TimeStructure{T}}
    TwoLevel(len::Integer, duration::S, oper::TimeStructure{T}; op_per_strat) where {S, T}
    TwoLevel(len::Integer, oper::TimeStructure{T}; op_per_strat) where {T}

    TwoLevel(duration::S, oper::Vector{OP}; op_per_strat) where {S, T, OP<:TimeStructure{T}}
    TwoLevel(duration::Vector{S}, oper::TimeStructure{T}; op_per_strat) where {S, T}

    TwoLevel(oper::Vector{<:TimeStructure{T}}; op_per_strat) where [T]

A time structure with two levels of time periods.

On the top level it has a sequence of strategic periods of varying duration.
For each strategic period a separate time structure is used for
operational decisions. Iterating the structure will go through all operational periods.
It is possible to use different time units for the two levels by providing the number
of operational time units per strategic time unit through the kewyord argument `op_per_strat`.

Potential time structures are [`SimpleTimes`](@ref), [`CalendarTimes`](@ref),
[`OperationalScenarios`](@ref), or [`RepresentativePeriods`](@ref), as well as combinations
of these.

!!! danger "Usage of op_per_strat"
    The optional keyword `op_per_strat` is important for the overall calculations.
    If you use an hourly resolution for your operational period and yearly for investment
    periods, then you have to specify it as `op_per_strat = 8760.0`. Not specifying it would
    imply that you use the same unit for strategic and operational periods.

!!! note "Not specifying the duration"
    If you do not specify the field `duration`, then it is calculated given the function

        _total_duration(op) / op_per_strat for op in oper

    in which `oper::Vector{<:TimeStructure{T}`. The internal function `_total_duration`
    corresponds in this case to the sum of the duration of all operational periods divided
    by the value of the field `op_per_strat`.

Example
```julia
# 5 years with 24 hours of operations for each year. Note that in this case we use as unit
# `hour` for both the duration of strategic periods and operational periods
TwoLevel(5, 8760, SimpleTimes(24, 1))

# The same time structure with the unit `year` for strategic periods and unit `hour` for
# operational periods
TwoLevel(5, 1, SimpleTimes(24, 1); op_per_strat=8760.0)

# All individual constructors
TwoLevel(2, ones(2), [SimpleTimes(24, 1), SimpleTimes(24, 1)], op_per_strat=8760.0)
TwoLevel(2, 1, SimpleTimes(24, 1); op_per_strat=8760.0)
TwoLevel(1, [SimpleTimes(24, 1), SimpleTimes(24, 1)]; op_per_strat=8760.0)
TwoLevel(ones(2), SimpleTimes(24, 1); op_per_strat=8760.0)

# Constructors without duration
TwoLevel([SimpleTimes(24, 1), SimpleTimes(24, 1)]; op_per_strat=8760.0)
TwoLevel(2, SimpleTimes(24, 1); op_per_strat=8760.0)
```
"""
struct TwoLevel{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    operational::Vector{OP}
    op_per_strat::Float64
    function TwoLevel(
        len::Integer,
        duration::Vector{S},
        operational::Vector{OP},
        op_per_strat::Float64,
    ) where {S<:Duration,T,OP<:TimeStructure{T}}
        if len > length(duration)
            throw(
                ArgumentError(
                    "The length of `duration` cannot be less than the field `len` of `TwoLevel`.",
                ),
            )
        elseif len > length(operational)
            throw(
                ArgumentError(
                    "The length of `operational` cannot be less than the field `len` of `TwoLevel`.",
                ),
            )
        end
        return new{S,T,OP}(len, duration, operational, op_per_strat)
    end
end

function TwoLevel(
    len::Integer,
    duration::S,
    oper::TimeStructure{T};
    op_per_strat = 1.0,
) where {S,T}
    return TwoLevel(
        len,
        fill(duration, len),
        fill(oper, len),
        convert(Float64, op_per_strat),
    )
end

function TwoLevel(
    duration::S,
    oper::Vector{OP};
    op_per_strat = 1.0,
) where {S,T,OP<:TimeStructure{T}}
    len = length(oper)
    return TwoLevel(len, fill(duration, len), oper, op_per_strat)
end

function TwoLevel(
    len::Integer,
    oper::TimeStructure{T};
    op_per_strat = 1.0,
) where {T}
    oper = fill(oper, len)
    dur = [_total_duration(op) / op_per_strat for op in oper]
    return TwoLevel(len, dur, oper, op_per_strat)
end

function TwoLevel(
    oper::Vector{<:TimeStructure{T}};
    op_per_strat = 1.0,
) where {T}
    len = length(oper)
    dur = [_total_duration(op) / op_per_strat for op in oper]
    return TwoLevel(len, dur, oper, op_per_strat)
end

function TwoLevel(
    duration::Vector{S},
    oper::TimeStructure{T};
    op_per_strat = 1.0,
) where {S,T}
    return TwoLevel(
        length(duration),
        duration,
        fill(oper, length(duration)),
        convert(Float64, op_per_strat),
    )
end

"""
    TwoLevel(len, duration::Real, oper::RepresentativePeriods)

Creates a TwoLevel time structure of given length using the same duration
and representative periods for each strategic period. The `op_per_strat` parameter
is set equal to the duration of the RepresentativePeriods structure to ensure consistency.

# Example
```julia
# 3 strategic periods of length 5 years, where each year of 365 day is represented by two weeks
periods = TwoLevel(3, 5, RepresentativePeriods(2, 365, [0.5, 0.5], [SimpleTimes(7,1), SimpleTimes(7,1)]))
```
"""
function TwoLevel(len::Integer, duration::Real, oper::RepresentativePeriods)
    return TwoLevel(
        len,
        fill(duration, len),
        fill(oper, len),
        convert(Float64, TimeStruct._total_duration(oper)),
    )
end

_total_duration(itr::TwoLevel) = sum(itr.duration)

function _multiple_adj(itr::TwoLevel, sp)
    mult =
        itr.duration[sp] * itr.op_per_strat /
        _total_duration(itr.operational[sp])
    return stripunit(mult)
end

function Base.iterate(itr::TwoLevel)
    sp = 1
    next = iterate(itr.operational[sp])
    next === nothing && return nothing
    per = next[1]

    mult = _multiple_adj(itr, sp) * multiple(per)
    return OperationalPeriod(sp, per, mult), (sp, next[2])
end

function Base.iterate(itr::TwoLevel, state)
    sp = state[1]
    next = iterate(itr.operational[sp], state[2])
    if next === nothing
        sp = sp + 1
        if sp > itr.len
            return nothing
        end
        next = iterate(itr.operational[sp])
    end
    per = next[1]

    mult = _multiple_adj(itr, sp) * multiple(per)
    return OperationalPeriod(sp, per, mult), (sp, next[2])
end

function Base.length(itr::TwoLevel)
    return sum(length(op) for op in itr.operational)
end

Base.eltype(::Type{TwoLevel{S,T,OP}}) where {S,T,OP} = OperationalPeriod

function Base.last(itr::TwoLevel)
    per = last(itr.operational[itr.len])
    mult = _multiple_adj(itr, itr.len) * multiple(per)
    return OperationalPeriod(itr.len, per, mult)
end

"""
	struct OperationalPeriod <: TimePeriod
Time period for iteration of a TwoLevel time structure.
"""
struct OperationalPeriod <: TimePeriod
    sp::Int
    period::TimePeriod
    multiple::Float64
end

isfirst(t::OperationalPeriod) = isfirst(t.period)
duration(t::OperationalPeriod) = duration(t.period)
probability(t::OperationalPeriod) = probability(t.period)
multiple(t::OperationalPeriod) = t.multiple

_oper(t::OperationalPeriod) = _oper(t.period)
_strat_per(t::OperationalPeriod) = t.sp
_opscen(t::OperationalPeriod) = _opscen(t.period)
_rper(t::OperationalPeriod) = _rper(t.period)

function Base.show(io::IO, t::OperationalPeriod)
    return print(io, "sp$(t.sp)-$(t.period)")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return t1.sp < t2.sp || (t1.sp == t2.sp && t1.period < t2.period)
end
