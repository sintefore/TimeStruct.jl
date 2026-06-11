# Add generic partition duration type
abstract type AbstractStratPart{T} <: PartitionDuration{T} end

StrategicIndexable(::Type{<:AbstractStratPart}) = HasStratIndex()
_strat_per(pd::AbstractStratPart) = pd.sp

# Add partition type with constructor for indexing when strategic periods are present
struct StratPart{N,T} <: AbstractStratPart{T}
    sp::Int
    part::Int
    chunk::NTuple{N,T}
end
PartitionDuration(itr::StrategicPeriod, part, chunk) = StratPart(itr.sp, part, chunk)
eltype(::Type{PartitionDurationIterator{I}}) where {I<:StrategicPeriod} = StratPart

Base.show(io::IO, pd::StratPart) = print(io, "sp$(pd.sp)-part$(pd.part)")

# Add partition type with constructor for indexing when strategic and representative periods
# are present
struct StratReprPart{N,T} <: AbstractStratPart{T}
    sp::Int
    rp::Int
    part::Int
    chunk::NTuple{N,T}
end
function PartitionDuration(itr::StratReprPeriod, part, chunk)
    return StratReprPart(itr.sp, itr.rp, part, chunk)
end
eltype(::Type{PartitionDurationIterator{I}}) where {I<:StratReprPeriod} = StratReprPart

Base.show(io::IO, pd::StratReprPart) = print(io, "sp$(pd.sp)-rp$(pd.rp)-part$(pd.part)")
RepresentativeIndexable(::Type{<:StratReprPart}) = HasReprIndex()
_rper(pd::StratReprPart) = pd.rp

# Add partition type with constructor for indexing when strategic periods and operational
# scenarios are present
struct StratOpScenPart{N,T} <: AbstractStratPart{T}
    sp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PartitionDuration(itr::StratOpScenario, part, chunk)
    return StratOpScenPart(itr.sp, itr.scen, part, chunk)
end
eltype(::Type{PartitionDurationIterator{I}}) where {I<:StratOpScenario} = StratOpScenPart

function Base.show(io::IO, pd::StratOpScenPart)
    return print(io, "sp$(pd.sp)-sc$(pd.scen)-part$(pd.part)")
end
ScenarioIndexable(::Type{<:StratOpScenPart}) = HasScenarioIndex()
_opscen(pd::StratOpScenPart) = pd.scen

# Add partition type with constructor for indexing when strategic periods, representative
# periods and operational scenarios are present
struct StratReprOpScenPart{N,T} <: AbstractStratPart{T}
    sp::Int
    rp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PartitionDuration(itr::StratReprOpScenario, part, chunk)
    return StratReprOpScenPart(itr.sp, itr.rp, itr.scen, part, chunk)
end
function eltype(::Type{PartitionDurationIterator{I}}) where {I<:StratReprOpScenario}
    return StratReprOpScenPart
end

function Base.show(io::IO, pd::StratReprOpScenPart)
    return print(io, "sp$(pd.sp)-rp$(pd.rp)-sc$(pd.scen)-part$(pd.part)")
end
RepresentativeIndexable(::Type{<:StratReprOpScenPart}) = HasReprIndex()
ScenarioIndexable(::Type{<:StratReprOpScenPart}) = HasScenarioIndex()
_rper(pd::StratReprOpScenPart) = pd.rp
_opscen(pd::StratReprOpScenPart) = pd.scen

# Add function for generation of partitions from higher level
function partition_duration(ts::TwoLevel, dur)
    return collect(
        Iterators.flatten(partition_duration(sp, dur) for sp in strategic_periods(ts)),
    )
end
function partition_duration(
    ts::StrategicPeriod{S,T,OP},
    dur,
) where {S,T,OP<:RepresentativePeriods}
    return collect(
        Iterators.flatten(partition_duration(rp, dur) for rp in repr_periods(ts)),
    )
end
function partition_duration(
    ts::StrategicPeriod{S,T,OP},
    dur,
) where {S,T,OP<:OperationalScenarios}
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
function partition_duration(
    ts::StratReprPeriod{T,RepresentativePeriod{T,OP}},
    dur,
) where {T,OP<:OperationalScenarios}
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
