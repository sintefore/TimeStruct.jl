"""
    Discounter

Structure to hold discount information to be used for a time structure.
"""
struct Discounter
    discount_rate::Any
    timeunit_to_year::Any
    ts::TimeStructure
end

Discounter(rate, ts) = Discounter(rate, 1.0, ts)

_start_strat(t::TimePeriod, ts::TimeStructure{T}) where {T} = zero(T)

function _start_strat(t::OperationalPeriod, ts::TwoLevel{S,T}) where {S,T}
    sp = _strat_per(t)
    if sp == 1
        return zero(S)
    end

    return sum(
        duration(spp) for spp in strat_periods(ts) if _strat_per(spp) < sp
    )
end

function _start_strat(sp::StrategicPeriod, ts::TwoLevel{S,T}) where {S,T}
    if _strat_per(sp) == 1
        return zero(S)
    end

    return sum(duration(spp) for spp in strat_periods(ts) if spp < sp)
end

function _to_year(start, disc)
    return start * disc.timeunit_to_year
end

function _to_year(start::Unitful.Quantity{V,Unitful.𝐓}, disc) where {V}
    return Unitful.ustrip(Unitful.uconvert(Unitful.u"yr", start))
end

function discount(disc::Discounter, t::TimePeriod; type = "start")
    start_year = _to_year(_start_strat(t, disc.ts), disc)
    duration_years = _to_year(duration(t), disc)

    multiplier = 1.0

    if type == "start"
        multiplier = discount_start(disc.discount_rate, start_year)
    elseif type == "avg"
        multiplier =
            discount_avg(disc.discount_rate, start_year, duration_years)
    end

    return multiplier
end

function discount_avg(discount_rate, start_year, duration_years)
    if discount_rate > 0
        δ = 1 / (1 + discount_rate)
        m =
            (δ^start_year - δ^(start_year + duration_years)) /
            log(1 + discount_rate) / duration_years
        return m
    else
        return 1.0
    end
end

function discount_start(discount_rate, start_year)
    δ = 1 / (1 + discount_rate)
    return δ^start_year
end

objective_weight(p, disc::Discounter) = 1.0

function objective_weight(p::SimplePeriod, disc::Discounter; type = "start")
    return discount(disc, p, type=type)
end

function objective_weight(op::OperationalPeriod, disc::Discounter; type = "start")
    return probability(op) * discount(disc, op, type=type) * multiple(op)
end

function objective_weight(sp::StrategicPeriod, disc::Discounter; type = "start")
    return discount(disc, sp, type=type)
end
