struct WithPrev{I}
    itr::I
end

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

function Base.last(sp::StrategicPeriod)
    if isa(sp.operational, OperationalScenarios)
        return error("last() not implemented for OperationalScenarios")
    end
    per = iterate(sp.operational, length(sp.operational) - 1)
    return OperationalPeriod(
        sp.sp,
        per[1],
        _multiple(per[1], sp.operational, sp),
    )
end
