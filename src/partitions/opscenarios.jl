# Add generic partition duration type
abstract type AbstractOpScenPart{T} <: PartitionDuration{T} end

ScenarioIndexable(::Type{<:AbstractOpScenPart}) = HasScenarioIndex()
_opscen(pd::AbstractOpScenPart) = pd.scen

# Add partition type with constructor for indexing when operational scenarios are present
struct OpScenPart{N,T} <: AbstractOpScenPart{T}
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
PartitionDuration(itr::OperationalScenario, part, chunk) = OpScenPart(itr.scen, part, chunk)
eltype(::Type{PartitionDurationIterator{I}}) where {I<:OperationalScenario} = OpScenPart

Base.show(io::IO, pd::OpScenPart) = print(io, "sc$(pd.scen)-part$(pd.part)")

# Add function for generation of partitions from higher level
function partition_duration(ts::OperationalScenarios, dur)
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
