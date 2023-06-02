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

function Base.last(ts::SimpleTimes)
    return SimplePeriod(ts.len, ts.duration[ts.len])
end

function Base.last(_::OperationalScenarios)
    return error("last() not implemented for OperationalScenarios")
end

function Base.last(sc::OperationalScenario)
    return ScenarioPeriod(sc.scen, sc.probability, last(sc.operational))
end

function Base.last(sp::StrategicPeriod)
    per = last(sp.operational)
    return OperationalPeriod(sp.sp, per, _multiple(per, sp.operational, sp))
end

function Base.last(sos::StratOperationalScenario)
    per = last(sos.operational)
    mult =
        stripunit(sos.duration * sos.op_per_strat / duration(sos.operational))
    return OperationalPeriod(sos.sp, per, mult)
end
