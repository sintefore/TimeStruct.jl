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

function Base.iterate(w::WithPrev{StratTreeNodes{T,OP}}) where {T,OP}
    n = iterate(w.itr)
    n === nothing && return n
    return (nothing, n[1]), (n[1], n[2])
end

function Base.iterate(w::WithPrev{StratTreeNodes{T,OP}}, state) where {T,OP}
    n = iterate(w.itr, state[2])
    n === nothing && return n
    return (n[1].parent, n[1]), (n[1], n[2])
end

struct Chunk{I}
    itr::I
    ns::Int
    cyclic::Bool
end

"""
    chunk(iter, n; cyclic = false)

Iterator wrapper that yields chunks where each chunk is an iterator over at most
`n` consecutive time periods starting at each time period of the original iterator.

It is possible to get the `n` consecutive time periods in a cyclic fashion, by
setting `cyclic` to true.
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
    next = Iterators.take(
        isnothing(state) ? itr : Iterators.rest(itr, state),
        w.ns,
    )
    return next, n[2]
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

Iterator wrapper that yields chunks based on duration where each chunk is an iterator over the following
time periods until at least `dur` time is covered or the end is reached.
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
    next = take_duration(
        isnothing(state) ? itr : Iterators.rest(itr, state...),
        w.duration,
    )
    return next, n[2]
end

function end_oper_time(t::TimePeriod, ts::SimpleTimes)
    return sum(duration(tt) for tt in ts if _oper(tt) <= _oper(t))
end

function end_oper_time(t::TimePeriod, ts::OperationalScenarios)
    return end_oper_time(t, ts.scenarios[_opscen(t)])
end

function end_oper_time(t::TimePeriod, ts::TwoLevel)
    return end_oper_time(t, ts.operational[_strat_per(t)])
end

function start_oper_time(t::TimePeriod, ts::TimeStructure)
    return end_oper_time(t, ts) - duration(t)
end

function expand_dataframe!(df, periods) end

# All introduced subtypes require the same procedures for the iteration and indexing.
# Hence, all introduced types use the same functions.
TreeStructure = Union{
    StratNodeOperationalScenario,
    StratNodeReprPeriod,
    StratNodeReprOpScenario,
}
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
    next =
        isnothing(state) ? iterate(ts.operational) :
        iterate(ts.operational, state)
    isnothing(next) && return nothing

    return TreePeriod(ts, next[1]), next[2]
end
