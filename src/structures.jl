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

Supertype of the iterators returned by [`strat_periods`](@ref), [`repr_periods`](@ref),
[`opscenarios`](@ref), and [`strategic_scenarios`](@ref) when called on the time structure
they iterate, *e.g.*, `opscenarios(OperationalScenarios())`. Iterating them yields
[`TimeStructurePeriod`](@ref)s instead of [`TimePeriod`](@ref)s.

Subtypes implement `iterate`, `length`, `Base.eltype` on the type, and
`getindex(itr, i::Int)` with a bounds check; `firstindex`, `eachindex`, and `keys` are
defined for all subtypes.
Iterators of strategic and representative periods also define `lastindex`, and hence
`itr[end]` and `last`, except for the nodes of a [`TwoLevelTree`](@ref) as there is no
unique last node. Iterators of scenarios have no `lastindex` as scenarios are not ordered.
"""
abstract type TimeStructInnerIter{T<:Duration} end

"""
    abstract type TimeStructOuterIter{T<:Duration}

Supertype of the iterators returned by [`repr_periods`](@ref) and [`opscenarios`](@ref)
when called on a [`TimeStructurePeriod`](@ref) containing the time structure they iterate,
*e.g.*, `opscenarios(StrategicPeriod())`. They wrap the corresponding
[`TimeStructInnerIter`](@ref) and provide the same interface.
"""
abstract type TimeStructOuterIter{T<:Duration} end

# Iterators returned by `strat_periods`, `repr_periods`, `opscenarios`, and
# `strategic_scenarios` are indexable sequences; each type only defines `getindex`
const TimeStructIter = Union{TimeStructInnerIter,TimeStructOuterIter}

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

Returns true if the time period is the first in a sequence and has no previous time period.

It is also defined for strategic periods, representative periods, and the partitions of
[`partition_duration`](@ref), as required by [`withprev`](@ref) and [`withnext`](@ref).
"""
isfirst(t::TimePeriod) = error("isfirst() not implemented for $(typeof(t))")

"""
    multiple(t::TimePeriod)

Returns the number of times a time period should be counted for the whole time
structure.
"""
multiple(t::TimePeriod) = 1.0

"""
    probability(t::TimePeriod)

Returns the probability associated with the time period. This include both the probability
through [`OperationalScenarios`](@ref) and through [`TwoLevelTree`](@ref) structures.
"""
probability(t::TimePeriod) = 1.0

"""
    probability_branch(t::Union{TimePeriod, TimeStructurePeriod})

Returns the branch probability associated with the time period or time structure period.
"""
probability_branch(t::Union{TimePeriod,TimeStructurePeriod}) = 1.0

# Functions used for indexing into time profiles
# TODO: Consider either setting all as default to one, including _oper, or none
_oper(t::TimePeriod) = error("_oper() not implemented for $(typeof(t))")
_opscen(t::TimePeriod) = 1
_rper(t::TimePeriod) = 1
_strat_per(t::TimePeriod) = 1
_branch(t::TimePeriod) = 1

# Returns the underlying time period for a hierarchical time period.
# The default implementation is to return the time period itself.
_period(t) = t

# Element type `X{P}`, or `X{<:P}` if `P` is abstract (sub-structures of different types)
_eltype(X, P) = isconcretetype(P) ? X{P} : X{<:P}

_total_duration(tss::Vector) = sum(duration(ts) for ts in tss)

_multiple_adj(ts::TimeStructure, per) = 1.0

stripunit(val) = val

"""
    abstract type PeriodPartition{T<:TimePeriod}

Supertype for individual partitions for operational time periods. Subtypes must be created
for all potential time structures to be able to identify the respective
[`TimeStructurePeriod`](@ref).
"""
abstract type PeriodPartition{T<:TimePeriod} end
function PeriodPartition(itr, part, chunk)
    return throw(
        ArgumentError(
            "`PeriodPartition` (used by `partition_duration`) is not implemented for " *
            "iterator type $(typeof(itr)).",
        ),
    )
end

Base.iterate(pd::PeriodPartition) = iterate(pd.chunk)
Base.iterate(pd::PeriodPartition, state) = iterate(pd.chunk, state)
Base.length(pd::PeriodPartition) = length(pd.chunk)
Base.first(pd::PeriodPartition) = first(pd.chunk)
Base.last(pd::PeriodPartition) = last(pd.chunk)

_part(pd::PeriodPartition) = pd.part
isfirst(pd::PeriodPartition) = _part(pd) == 1

abstract type PartitionIndexable end

struct HasPartIndex <: PartitionIndexable end
struct NoPartIndex <: PartitionIndexable end

PartitionIndexable(::Type) = NoPartIndex()
PartitionIndexable(::Type{<:PeriodPartition}) = HasPartIndex()
