"""
    struct TwoLevel{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}

    TwoLevel(len::Integer, duration::Vector{S}, operational::Vector{OP}, op_per_strat::Float64) where {S<:Duration, T, OP<:TimeStructure{T}}
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

function TwoLevel(len::Integer, oper::TimeStructure{T}; op_per_strat = 1.0) where {T}
    oper = fill(oper, len)
    dur = [_total_duration(op) / op_per_strat for op in oper]
    return TwoLevel(len, dur, oper, op_per_strat)
end

function TwoLevel(oper::Vector{<:TimeStructure{T}}; op_per_strat = 1.0) where {T}
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

_total_duration(ts::TwoLevel) = sum(ts.duration)

function _multiple_adj(ts::TwoLevel, sp)
    mult = ts.duration[sp] * ts.op_per_strat / _total_duration(ts.operational[sp])
    return stripunit(mult)
end

# Add basic functions of iterators
function Base.length(ts::TwoLevel)
    return sum(length(op) for op in ts.operational)
end
Base.eltype(::Type{TwoLevel{S,T,OP}}) where {S,T,OP} = OperationalPeriod{eltype(OP)}
function Base.iterate(ts::TwoLevel, state = (nothing, 1))
    sp = state[2]
    next =
        isnothing(state[1]) ? iterate(ts.operational[sp]) :
        iterate(ts.operational[sp], state[1])
    if next === nothing
        sp = sp + 1
        if sp > ts.len
            return nothing
        end
        next = iterate(ts.operational[sp])
    end
    return OperationalPeriod(ts, next[1], sp), (next[2], sp)
end
function Base.last(ts::TwoLevel)
    per = last(ts.operational[ts.len])
    return OperationalPeriod(ts, per, ts.len)
end

"""
	struct OperationalPeriod{P} <: TimePeriod where {P<:TimePeriod}

Time period for a single operational period. It is created through iterating through a
[`TwoLevel`](@ref) time structure.
"""
struct OperationalPeriod{P} <: TimePeriod where {P<:TimePeriod}
    sp::Int
    period::P
    multiple::Float64
end
_period(t::OperationalPeriod) = t.period

_strat_per(t::OperationalPeriod) = t.sp
_rper(t::OperationalPeriod) = _rper(_period(t))
_opscen(t::OperationalPeriod) = _opscen(_period(t))
_oper(t::OperationalPeriod) = _oper(_period(t))

isfirst(t::OperationalPeriod) = isfirst(_period(t))
duration(t::OperationalPeriod) = duration(_period(t))
multiple(t::OperationalPeriod) = t.multiple
probability(t::OperationalPeriod) = probability(_period(t))

function Base.show(io::IO, t::OperationalPeriod)
    return print(io, "sp$(_strat_per(t))-$(_period(t))")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return _strat_per(t1) < _strat_per(t2) ||
           (_strat_per(t1) == _strat_per(t2) && _period(t1) < _period(t2))
end

# Convenience constructor for the type
function OperationalPeriod(ts::TwoLevel, per::TimePeriod, sp::Int)
    mult = _multiple_adj(ts, sp) * multiple(per)
    return OperationalPeriod(sp, per, mult)
end
