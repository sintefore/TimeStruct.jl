# Add generic partition duration type
abstract type AbstractTreePart{T} <: AbstractStratPart{T} end

StrategicTreeIndexable(::Type{<:AbstractTreePart}) = HasStratTreeIndex()
_branch(pd::AbstractTreePart) = pd.branch

# Add partition type with constructor for indexing when strategic periods are present
struct StratNodePart{N,T} <: AbstractTreePart{T}
    sp::Int
    branch::Int
    part::Int
    chunk::NTuple{N,T}
end
function PeriodPartition(itr::StratNode, part, chunk)
    return StratNodePart(_strat_per(itr), _branch(itr), part, chunk)
end
eltype(::Type{PartitionDurationIterator{I,T,D}}) where {I<:StratNode,T,D} = StratNodePart

function Base.show(io::IO, pd::StratNodePart)
    return print(io, "sp$(_strat_per(pd))-br$(_branch(pd))-part$(_part(pd))")
end

# Add partition type with constructor for indexing when strategic and representative periods
# are present
struct StratNodeReprPart{N,T} <: AbstractTreePart{T}
    sp::Int
    branch::Int
    rp::Int
    part::Int
    chunk::NTuple{N,T}
end
function PeriodPartition(itr::StratNodeReprPeriod, part, chunk)
    return StratNodeReprPart(_strat_per(itr), _branch(itr), _rper(itr), part, chunk)
end
function eltype(::Type{PartitionDurationIterator{I,T,D}}) where {I<:StratNodeReprPeriod,T,D}
    return StratNodeReprPart
end

RepresentativeIndexable(::Type{<:StratNodeReprPart}) = HasReprIndex()
_rper(pd::StratNodeReprPart) = pd.rp

function Base.show(io::IO, pd::StratNodeReprPart)
    return print(io, "sp$(_strat_per(pd))-br$(_branch(pd))-rp$(_rper(pd))-part$(_part(pd))")
end

# Add partition type with constructor for indexing when strategic periods and operational
# scenarios are present
struct StratNodeOpScenPart{N,T} <: AbstractTreePart{T}
    sp::Int
    branch::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PeriodPartition(itr::StratNodeOpScenario, part, chunk)
    return StratNodeOpScenPart(_strat_per(itr), _branch(itr), _opscen(itr), part, chunk)
end
function eltype(::Type{PartitionDurationIterator{I,T,D}}) where {I<:StratNodeOpScenario,T,D}
    return StratNodeOpScenPart
end

function Base.show(io::IO, pd::StratNodeOpScenPart)
    return print(
        io,
        "sp$(_strat_per(pd))-br$(_branch(pd))-sc$(_opscen(pd))-part$(_part(pd))",
    )
end
ScenarioIndexable(::Type{<:StratNodeOpScenPart}) = HasScenarioIndex()
_opscen(pd::StratNodeOpScenPart) = pd.scen

# Add partition type with constructor for indexing when strategic periods, representative
# periods and operational scenarios are present
struct StratNodeReprOpScenPart{N,T} <: AbstractTreePart{T}
    sp::Int
    branch::Int
    rp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PeriodPartition(itr::StratNodeReprOpScenario, part, chunk)
    return StratNodeReprOpScenPart(
        _strat_per(itr),
        _branch(itr),
        _rper(itr),
        _opscen(itr),
        part,
        chunk,
    )
end
function eltype(
    ::Type{PartitionDurationIterator{I,T,D}},
) where {I<:StratNodeReprOpScenario,T,D}
    return StratNodeReprOpScenPart
end

function Base.show(io::IO, pd::StratNodeReprOpScenPart)
    return print(
        io,
        "sp$(_strat_per(pd))-br$(_branch(pd))-rp$(_rper(pd))-sc$(_opscen(pd))-part$(_part(pd))",
    )
end
RepresentativeIndexable(::Type{<:StratNodeReprOpScenPart}) = HasReprIndex()
ScenarioIndexable(::Type{<:StratNodeReprOpScenPart}) = HasScenarioIndex()
_rper(pd::StratNodeReprOpScenPart) = pd.rp
_opscen(pd::StratNodeReprOpScenPart) = pd.scen

# Add function for generation of partitions from higher level
function partition_duration(ts::TwoLevelTree, dur)
    return collect(
        Iterators.flatten(partition_duration(sp, dur) for sp in strategic_periods(ts)),
    )
end
function partition_duration(
    ts::StratNode{S,T,OP},
    dur,
) where {S,T,OP<:RepresentativePeriods}
    return collect(
        Iterators.flatten(partition_duration(rp, dur) for rp in repr_periods(ts)),
    )
end
function partition_duration(ts::StratNode{S,T,OP}, dur) where {S,T,OP<:OperationalScenarios}
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
function partition_duration(
    ts::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}},
    dur,
) where {T,OP<:OperationalScenarios}
    return collect(
        Iterators.flatten(partition_duration(osc, dur) for osc in opscenarios(ts)),
    )
end
