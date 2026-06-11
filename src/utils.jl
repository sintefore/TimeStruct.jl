struct WithPrev{I}
    itr::I
end

"""
    withprev(iter)

Iterator wrapper that yields `(prev, t)` where `prev`
is the previous time period or `nothing` for the first
time period.
"""
withprev(iter) = WithPrev(iter)
Base.length(w::WithPrev) = length(w.itr)
Base.size(w::WithPrev) = size(w.itr)

function Base.iterate(w::WithPrev)
    n = iterate(w.itr)
    n === nothing && return n
    return (nothing, n[1]), (n[1], n[2])
end

function Base.iterate(w::WithPrev, state)
    n = iterate(w.itr, state[2])
    n === nothing && return n
    return (isfirst(n[1]) ? nothing : state[1], n[1]), (n[1], n[2])
end

function Base.iterate(w::WithPrev{StratTreeNodes{S,T,OP}}) where {S,T,OP}
    n = iterate(w.itr)
    n === nothing && return n
    return (nothing, n[1]), (n[1], n[2])
end

function Base.iterate(w::WithPrev{StratTreeNodes{S,T,OP}}, state) where {S,T,OP}
    n = iterate(w.itr, state[2])
    n === nothing && return n
    return (n[1].parent, n[1]), (n[1], n[2])
end

struct WithNext{I}
    itr::I
end

"""
    withnext(iter)

Iterator wrapper that yields `(t, next)` where `next`
is the next time period or `nothing` for the last
time period.

Note that this iterator can not be used when iterating the
nodes of a strategic tree structure, as the next
node is not uniquely defined in that case.
"""
withnext(iter) = WithNext(iter)
Base.length(w::WithNext) = length(w.itr)
Base.size(w::WithNext) = size(w.itr)

function Base.iterate(w::WithNext, state = nothing)
    n = isnothing(state) ? iterate(w.itr) : iterate(w.itr, state[2])
    n === nothing && return n
    nn = iterate(w.itr, n[2])
    if isnothing(nn) || isfirst(nn[1])
        next = nothing
    else
        next = nn[1]
    end
    return (n[1], next), (n[1], n[2])
end

function WithNext(_::StratTreeNodes{S,T,OP}) where {S,T,OP}
    return error(
        "withnext can not be used when iterating nodes of a strategic tree structure.",
    )
end

struct Chunk{I}
    itr::I
    ns::Int
    cyclic::Bool
end

"""
    chunk(iter, n; cyclic = false)

Iterator wrapper that yields chunks where each chunk is an iterator over at most `n`
consecutive time periods starting at each time period of the original iterator.

It is possible to get the `n` consecutive time periods in a cyclic fashion, by setting
`cyclic` to true.

!!! warning "TwoLevelTree"
    Usage of the function for the strategic periods of a [`TwoLevelTree`](@ref) time
    structure results in an error.
"""
chunk(iter, n; cyclic = false) = Chunk(iter, n, cyclic)
Base.length(w::Chunk) = length(w.itr)
Base.size(w::Chunk) = size(w.itr)

function Base.iterate(w::Chunk, state = nothing)
    n = isnothing(state) ? iterate(w.itr) : iterate(w.itr, state)
    n === nothing && return n
    itr = w.itr
    if w.cyclic
        itr = Iterators.cycle(w.itr)
    end
    next = Iterators.take(isnothing(state) ? itr : Iterators.rest(itr, state), w.ns)
    return next, n[2]
end

function chunk(_::StratTreeNodes{S,T,OP}, _) where {S,T,OP}
    return error(
        "`chunk` can not be used when iterating nodes of a strategic tree structure.",
    )
end

struct TakeDuration{I}
    xs::I
    duration::Duration
end

take_duration(xs, dur::Duration) = TakeDuration(xs, dur)

IteratorSize(::Type{<:TakeDuration}) = Base.SizeUnknown()
eltype(::Type{TakeDuration{I}}) where {I} = eltype(I)
IteratorEltype(::Type{TakeDuration{I}}) where {I} = IteratorEltype(I)

function Base.iterate(it::TakeDuration, state = (it.duration,))
    dur, rest = state[1], Base.tail(state)
    dur <= 0 && return nothing
    y = iterate(it.xs, rest...)
    y === nothing && return nothing
    return y[1], (dur - duration(y[1]), y[2])
end

struct ChunkDuration{I}
    itr::I
    duration::Duration
    cyclic::Bool
end

"""
    chunk_duration(iter, dur)

Iterator wrapper that yields chunks based on duration where each chunk is an iterator over
the following time periods until at least `dur` time is covered or the end is reached.

!!! warning "TwoLevelTree"
    Usage of the function for the strategic periods of a [`TwoLevelTree`](@ref) time
    structure results in an error.
"""
chunk_duration(iter, dur; cyclic = false) = ChunkDuration(iter, dur, cyclic)

eltype(::Type{ChunkDuration{I}}) where {I} = eltype(I)
IteratorEltype(::Type{ChunkDuration{I}}) where {I} = IteratorEltype(I)
length(w::ChunkDuration) = length(w.itr)

function Base.iterate(w::ChunkDuration, state = nothing)
    n = isnothing(state) ? iterate(w.itr) : iterate(w.itr, state)
    n === nothing && return n
    itr = w.itr
    if w.cyclic
        itr = Iterators.cycle(w.itr)
    end
    next = take_duration(isnothing(state) ? itr : Iterators.rest(itr, state...), w.duration)
    return next, n[2]
end

function chunk_duration(_::StratTreeNodes{S,T,OP}, _) where {S,T,OP}
    return error(
        "`chunk_duration` can not be used when iterating nodes of a strategic tree structure.",
    )
end

"""
    abstract type PartitionDuration{T<:TimePeriod}

Supertype for individual partitions based on durations for operational time periods. Subtypes
must be created for all potential time structures to be able to identify the respective
[`TimeStructureperiod`](@ref).
"""

abstract type PartitionDuration{T<:TimePeriod} end

Base.iterate(pd::PartitionDuration) = iterate(pd.chunk)
Base.iterate(pd::PartitionDuration, state) = iterate(pd.chunk, state)
Base.length(pd::PartitionDuration) = length(pd.chunk)
Base.first(pd::PartitionDuration) = first(pd.chunk)
Base.last(pd::PartitionDuration) = last(pd.chunk)

abstract type PartitionIndexable end

struct HasPartIndex <: PartitionIndexable end
struct NoPartIndex <: PartitionIndexable end

PartitionIndexable(::Type) = NoPartIndex()
PartitionIndexable(::Type{<:PartitionDuration}) = HasPartIndex()

struct PartitionDurationIterator{I<:TimeStructure}
    itr::I
    duration::TimeStruct.Duration
end

"""
    partition_duration(itr, dur)

Iterator wrapper that yields partitions of time periods where each partition is an iterator
over the following time periods until at least `dur` time is covered or the end is reached.


!!! note "Application"
    The partitions only cover time periods within an operational scenario, representative
    period, or strategic period depending on the chosen time structure.

    The reason for this approach is the lack of meaning a partition of a
    [`TimeStructurePeriod`](@ref)
"""
partition_duration(itr, dur) = PartitionDurationIterator(itr, dur)

IteratorSize(::Type{<:PartitionDurationIterator}) = Base.SizeUnknown()
IteratorEltype(::Type{PartitionDurationIterator{I}}) where {I} = Base.HasEltype()

function Base.iterate(w::PartitionDurationIterator, state = (nothing, 1))
    isa(state[1], Iterators.IterationCutShort) && return nothing
    y = iterate(w.itr, state[1])
    isnothing(y) && return nothing
    part = state[2]
    chunk = eltype(w.itr)[]
    acc = zero(w.duration)
    while !isnothing(y)
        push!(chunk, y[1])
        acc += duration(y[1])
        acc >= w.duration && break
        y = iterate(w.itr, y[2])
    end
    pd = PartitionDuration(w.itr, part, Tuple(chunk))
    isnothing(y) && return pd, (Iterators.IterationCutShort(), part+1)
    return pd, (y[2], part+1)
end

struct StratPart{N,T} <: PartitionDuration{T}
    sp::Int
    part::Int
    chunk::NTuple{N,T}
end
PartitionDuration(itr::StrategicPeriod, part, chunk) = StratPart(itr.sp, part, chunk)
eltype(::Type{PartitionDurationIterator{I}}) where {I<:StrategicPeriod} = StratPart

Base.show(io::IO, pd::StratPart) = print(io, "sp$(pd.sp)-part$(pd.part)")
StrategicIndexable(::Type{<:StratPart}) = HasStratIndex()

_strat_per(pd::StratPart) = pd.sp
_part(pd::StratPart) = pd.part

struct StratReprPart{N,T} <: PartitionDuration{T}
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
StrategicIndexable(::Type{<:StratReprPart}) = HasStratIndex()
RepresentativeIndexable(::Type{<:StratReprPart}) = HasReprIndex()

_strat_per(pd::StratReprPart) = pd.sp
_rper(pd::StratReprPart) = pd.rp
_part(pd::StratReprPart) = pd.part

struct StratOpScenPart{N,T} <: PartitionDuration{T}
    sp::Int
    scen::Int
    part::Int
    chunk::NTuple{N,T}
end
function PartitionDuration(itr::StratOpScenario, part, chunk)
    return StratOpScenPart(itr.sp, itr.scen, part, chunk)
end
eltype(::Type{PartitionDurationIterator{I}}) where {I<:StratOpScenario} = StratOpScenPart

Base.show(io::IO, pd::StratOpScenPart) = print(io, "sp$(pd.sp)-sc$(pd.scen)-part$(pd.part)")
StrategicIndexable(::Type{<:StratOpScenPart}) = HasStratIndex()
ScenarioIndexable(::Type{<:StratOpScenPart}) = HasScenarioIndex()

_strat_per(pd::StratOpScenPart) = pd.sp
_opscen(pd::StratOpScenPart) = pd.scen
_part(pd::StratOpScenPart) = pd.part

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

"""
    end_oper_time(t, ts)

Get the operational end time of the time period `t` in the time structure `ts`.

The operational end time is equal to the sum of the durations of all previous
operational time periods in its operational time structure, including its own
duration.

!!! warning
    The current implementation is not computationally efficient and should be
    avoided if using this in loops for time structures with many time periods.
    If this is the case, consider implementing a local tracking of end time
    using the duration of the time periods.
"""
function end_oper_time(t::TimePeriod, ts::TimeStructure)
    return error("end_oper_time not implemented for time structure: $(ts)")
end

function end_oper_time(t::TimePeriod, ts::Union{SimpleTimes,CalendarTimes})
    return sum(duration(tt) for tt in ts if _oper(tt) <= _oper(t))
end

function end_oper_time(t::TimePeriod, ts::RepresentativePeriods)
    return end_oper_time(t, ts.rep_periods[_rper(t)])
end

function end_oper_time(t::TimePeriod, ts::OperationalScenarios)
    return end_oper_time(t, ts.scenarios[_opscen(t)])
end

function end_oper_time(t::TimePeriod, ts::TwoLevel)
    return end_oper_time(t, ts.operational[_strat_per(t)])
end

function end_oper_time(t::TimePeriod, ts::TwoLevelTree)
    node = filter(n -> _strat_per(n) == _strat_per(t) && _branch(n) == _branch(t), ts.nodes)
    @assert length(node) == 1
    return end_oper_time(t, node[1].operational)
end

"""
    start_oper_time(t, ts)

Get the operational start time of the time period `t` in the time structure `ts`.

The operational start time is equal to the sum of the durations of all previous
operational time periods in its operational time structure.

!!! warning
    The current implementation is not computationally efficient and should be
    avoided if using this in loops for time structures with many time periods.
    If this is the case, consider implementing a local tracking of start time
    using the duration of the time periods.
"""
function start_oper_time(t::TimePeriod, ts::TimeStructure)
    return end_oper_time(t, ts) - duration(t)
end

function expand_dataframe!(df, periods) end

# All introduced subtypes require the same procedures for the iteration and indexing.
# Hence, all introduced types use the same functions.
TreeStructure = Union{StratNodeOpScenario,StratNodeReprPeriod,StratNodeReprOpScenario}
Base.length(ts::TreeStructure) = length(ts.operational)
function Base.last(ts::TreeStructure)
    per = last(ts.operational)
    return TreePeriod(ts, per)
end

function Base.getindex(ts::TreeStructure, index)
    per = ts.operational[index]
    return TreePeriod(ts, per)
end
function Base.eachindex(ts::TreeStructure)
    return eachindex(ts.operational)
end
function Base.iterate(ts::TreeStructure, state = nothing)
    next = isnothing(state) ? iterate(ts.operational) : iterate(ts.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(ts, next[1]), next[2]
end
