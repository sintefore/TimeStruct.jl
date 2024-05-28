"""
    struct TwoLevel <: TimeStructure

A time structure with two levels of time periods.

On the top level it has a sequence of strategic periods of varying duration.
For each strategic period a separate time structure is used for
operational decisions. Iterating the structure will go through all operational periods.
It is possible to use different time units for the two levels by providing the number
of operational time units per strategic time unit.

Example
```julia
periods = TwoLevel(5, 8760, SimpleTimes(24, 1)) # 5 years with 24 hours of operations for each year
```
"""
struct TwoLevel{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    operational::Vector{OP}
    op_per_strat::Float64
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
    return TwoLevel{S,T,OP}(len, fill(duration, len), oper, op_per_strat)
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
