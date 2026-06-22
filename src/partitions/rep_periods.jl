# Add generic partition duration type
abstract type AbstractReprPart{T} <: PeriodPartition{T} end

RepresentativeIndexable(::Type{<:AbstractReprPart}) = HasReprIndex()
_rper(pd::AbstractReprPart) = pd.rp

# Add partition type with constructor for indexing when representative periods are present
struct ReprPart{N,T} <: AbstractReprPart{T}
    rp::Int
    part::Int
    chunk::NTuple{N,T}
end
PeriodPartition(itr::RepresentativePeriod, part, chunk) = ReprPart(itr.rp, part, chunk)
function eltype(
    ::Type{PartitionDurationIterator{I,T,D}},
) where {I<:RepresentativePeriod,T,D}
    return ReprPart
end

Base.show(io::IO, pd::ReprPart) = print(io, "rp$(pd.rp)-part$(pd.part)")

# Add partition type with constructor for indexing when representative periods and operational
# scenarios are present
struct ReprOpScenPart{N,T} <: AbstractReprPart{T}
    rp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PeriodPartition(itr::ReprOpScenario, part, chunk)
    return ReprOpScenPart(itr.rp, itr.scen, part, chunk)
end
function eltype(::Type{PartitionDurationIterator{I,T,D}}) where {I<:ReprOpScenario,T,D}
    return ReprOpScenPart
end

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
