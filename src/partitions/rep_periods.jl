# Add generic partition duration type
abstract type AbstractReprPart{T} <: PartitionDuration{T} end

RepresentativeIndexable(::Type{<:AbstractReprPart}) = HasReprIndex()
_rper(pd::AbstractReprPart) = pd.rp

# Add partition type with constructor for indexing when representative periods are present
struct ReprPart{N,T} <: AbstractReprPart{T}
    rp::Int
    part::Int
    chunk::NTuple{N,T}
end
PartitionDuration(itr::RepresentativePeriod, part, chunk) = ReprPart(itr.rp, part, chunk)
eltype(::Type{PartitionDurationIterator{I}}) where {I<:RepresentativePeriod} = ReprPart

Base.show(io::IO, pd::ReprPart) = print(io, "rp$(pd.rp)-part$(pd.part)")

# Add partition type with constructor for indexing when representative periods and operational
# scenarios are present
struct ReprOpScenPart{N,T} <: AbstractReprPart{T}
    rp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PartitionDuration(itr::ReprOpScenario, part, chunk)
    return ReprOpScenPart(itr.rp, itr.scen, part, chunk)
end
eltype(::Type{PartitionDurationIterator{I}}) where {I<:ReprOpScenario} = ReprOpScenPart

Base.show(io::IO, pd::ReprOpScenPart) = print(io, "rp$(pd.rp)-sc$(pd.scen)-part$(pd.part)")
ScenarioIndexable(::Type{<:ReprOpScenPart}) = HasScenarioIndex()
_opscen(pd::ReprOpScenPart) = pd.scen

# Add function for generation of partitions from higher level
function partition_duration(ts::RepresentativePeriods, dur)
    return collect(
        Iterators.flatten(partition_duration(rp, dur) for rp in repr_periods(ts)),
    )
end
function partition_duration(
    ts::RepresentativePeriod{T,OP},
    dur,
) where {T,OP<:OperationalScenarios}
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
