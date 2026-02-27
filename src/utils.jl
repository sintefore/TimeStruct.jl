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

function end_oper_time(t::TimePeriod, opscen::AbstractOperationalScenario)
    return end_oper_time(t, opscen.operational)
end

function end_oper_time(t::TimePeriod, ts::RepresentativePeriods)
    return end_oper_time(t, ts.rep_periods[_rper(t)])
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

function profilechart end
function profilechart! end

_scen(sc::AbstractOperationalScenario) = "sc-$(TimeStruct._opscen(sc))"
_repr(rp::AbstractRepresentativePeriod) = "rp-$(TimeStruct._rper(rp))"
_strat(sp::AbstractStrategicPeriod) = "sp-$(TimeStruct._strat_per(sp))"

function rowtable(profile::TimeProfile, periods::SimpleTimes; include_end = true)
    rowtable = []
    for t in periods
        push!(rowtable, (t = start_oper_time(t, periods), value = profile[t]))
    end
    if include_end
        last_period = last(periods)
        push!(
            rowtable,
            (t = end_oper_time(last_period, periods), value = profile[last_period]),
        )
    end
    return rowtable
end

function rowtable(profile::TimeProfile, periods::OperationalScenarios; include_end = true)
    rowtable = []
    for sc in opscenarios(periods)
        for t in sc
            push!(
                rowtable,
                (opscen = _scen(sc), t = start_oper_time(t, periods), value = profile[t]),
            )
        end
        if include_end
            last_period = last(sc)
            push!(
                rowtable,
                (
                    opscen = _scen(sc),
                    t = end_oper_time(last_period, periods),
                    value = profile[last_period],
                ),
            )
        end
    end
    return rowtable
end

function rowtable(profile::TimeProfile, periods::TwoLevel; include_end = true)
    rowtable = []
    for sp in strat_periods(periods)
        for rp in repr_periods(sp)
            for sc in opscenarios(rp)
                for t in sc
                    push!(
                        rowtable,
                        (
                            strat = _strat(sp),
                            repr = _repr(rp),
                            opscen = _scen(sc),
                            t = start_oper_time(t, periods),
                            value = profile[t],
                        ),
                    )
                end
                if include_end
                    last_period = last(sc)
                    push!(
                        rowtable,
                        (
                            strat = _strat(sp),
                            repr = _repr(rp),
                            opscen = _scen(sc),
                            t = end_oper_time(last_period, periods),
                            value = profile[last_period],
                        ),
                    )
                end
            end
        end
    end
    return rowtable
end
