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

struct Slice{I}
    itr::I
    ns::Int
    cyclic::Bool
end

"""
    slice(iter, n; cyclic = false)

Iterator wrapper that yields slices where each slice is an iterator over at most
`n` consecutive time periods starting at each time period of the original iterator.

It is possible to get the `n` consecutive time periods in a cyclic fashion, by
setting `cyclic` to true.
"""
slice(iter, n; cyclic = false) = Slice(iter, n, cyclic)
Base.length(w::Slice) = length(w.itr)
Base.size(w::Slice) = size(w.itr)

function Base.iterate(w::Slice, state = nothing)
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

struct SliceDuration{I}
    itr::I
    duration::Duration
    cyclic::Bool
end

"""
    slice_duration(iter, dur)

Iterator wrapper that yields slices based on duration where each slice is an iterator over the following
time periods until at least `dur` time is covered or the end is reached.
"""
slice_duration(iter, dur; cyclic = false) = SliceDuration(iter, dur, cyclic)

eltype(::Type{SliceDuration{I}}) where {I} = eltype(I)
IteratorEltype(::Type{SliceDuration{I}}) where {I} = IteratorEltype(I)
length(w::SliceDuration) = length(w.itr)

function Base.iterate(w::SliceDuration, state = nothing)
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

function Base.last(ts::SimpleTimes)
    return SimplePeriod(ts.len, ts.duration[ts.len])
end

function Base.last(_::OperationalScenarios)
    return error("last() not implemented for OperationalScenarios")
end

function Base.last(sc::OperationalScenario)
    return ScenarioPeriod(
        sc.scen,
        sc.probability,
        sc.multiple,
        last(sc.operational),
    )
end

function Base.last(rp::RepresentativePeriod)
    per = last(rp.operational)
    mult = stripunit(rp.duration * rp.per_share / duration(rp.operational))
    return ReprPeriod(rp.rper, per, mult)
end

function Base.last(srp::StratReprPeriod)
    per = last(srp.operational)
    mult = stripunit(srp.duration_sp * srp.op_per_strat / srp.duration_rp)
    return OperationalPeriod(srp.sp, per, mult * multiple(per))
end

function Base.last(sp::StrategicPeriod)
    per = last(sp.operational)
    mult = stripunit(duration(sp) * sp.op_per_strat / duration(sp.operational))
    return OperationalPeriod(sp.sp, per, mult * multiple(per))
end

function Base.last(sos::StratOperationalScenario)
    per = last(sos.operational)
    mult =
        stripunit(sos.duration * sos.op_per_strat / duration(sos.operational))
    return OperationalPeriod(sos.sp, per, mult * multiple(per))
end

function Base.last(reps::StratReprPeriods)
    per = last(collect(reps.rperiods))

    return StratReprPeriod(
        reps.sper.sp,
        per.rper,
        duration(reps.sper),
        duration(reps.rperiods.ts),
        per,
        reps.sper.op_per_strat,
    )
end
