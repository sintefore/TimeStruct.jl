# Durations can be provided as any number
Duration = Number

"""
    abstract type TimeStructure{T<:Duration}

Abstract type representing different time structures that consists of one or more time
periods.

The type 'T' gives the data type used for the duration of the time periods.
"""
abstract type TimeStructure{T<:Duration} end

"""
    abstract type TimeStructurePeriod{T} <: TimeStructure{T}

Abstract type representing different time structures that consists of one or more time
periods. It is used for `TimeStructure`s that can also act as index for periods, *e.g.*,
[`AbstractStrategicPeriod`](@ref).

The type 'T' gives the data type used for the duration of the time periods.
"""
abstract type TimeStructurePeriod{T} <: TimeStructure{T} end

"""
    abstract type TimeStructInnerIter{T<:Duration}

Abstract type representing different iterators for individual time structures.
The difference to [`TimeStructure`](@ref) is that iterating through a `TimeStructInnerIter`
will not provide a [`TimePeriod`](@ref), but a [`TimeStructure`](@ref).

!!! note
    `TimeStructInnerIter` and [`TimeStructOuterIter`](@ref) are comparable. The
    former is implemented for the inner level, that is if you want to use, _e.g._,
    `opscenarios(OperationalScenarios())` while the latter is used for the outer level,
    _e.g._, `opscenarios(StrategicPeriod())`.
"""
abstract type TimeStructInnerIter{T<:Duration} end

"""
    abstract type TimeStructOuterIter{T<:Duration}

Abstract type representing different iterators for individual time structures.
The difference to [`TimeStructure`](@ref) is that iterating through a `TimeStructOuterIter`
will not provide a [`TimePeriod`](@ref), but a [`TimeStructure`](@ref).

!!! note
    [`TimeStructInnerIter`](@ref) and `TimeStructOuterIter` are comparable. The
    former is implemented for the inner level, that is if you want to use, _e.g._,
    `opscenarios(OperationalScenarios())` while the latter is used for the outer level,
    _e.g._, `opscenarios(StrategicPeriod())`.
"""
abstract type TimeStructOuterIter{T<:Duration} end

"""
    abstract type TimePeriod

Abstract type used for a uniform interface for iterating through
time structures and indexing of time profiles.
"""
abstract type TimePeriod end

"""
    duration(t::TimePeriod)

The duration of a time period in number of operational time units.
"""
duration(t::TimePeriod) = error("duration() not implemented for $(typeof(t))")

"""
    isfirst(t::TimePeriod)

Returns true if the time period is the first in a sequence and has no previous time period
"""
isfirst(t::TimePeriod) = error("isfirst() not implemented for$(typeof(t))")

"""
    multiple(t::TimePeriod)

Returns the number of times a time period should be counted for the whole time
structure.
"""
multiple(t::TimePeriod) = 1.0

"""
    probability(t::TimePeriod)
Returns the probability associated with the time period.
"""
probability(t::TimePeriod) = 1.0

# Functions used for indexing into time profiles
# TODO: Consider either setting all as default to one, including _oper, or none
_oper(t::TimePeriod) = error("_oper() not implemented for $(typeof(t))")
_opscen(t::TimePeriod) = 1
_rper(t::TimePeriod) = 1
_strat_per(t::TimePeriod) = 1
_branch(t::TimePeriod) = 1

_total_duration(tss::Vector) = sum(duration(ts) for ts in tss)

_multiple_adj(ts::TimeStructure, per) = 1.0

stripunit(val) = val

multiple(ts::TimeStructure, t::TimePeriod) = 1.0
