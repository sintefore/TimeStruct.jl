"""
    Discounter(discount_rate, timeunit_to_year, ts)

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
        duration_strat(spp) for spp in strat_periods(ts) if _strat_per(spp) < sp
    )
end

function _start_strat(
    sp::AbstractStrategicPeriod,
    ts::TwoLevel{S,T},
) where {S,T}
    if _strat_per(sp) == 1
        return zero(S)
    end

    return sum(duration_strat(spp) for spp in strat_periods(ts) if spp < sp)
end

function _to_year(start, timeunit_to_year)
    return start * timeunit_to_year
end



"""
    discount(t, time_struct, discount_rate; type, timeunit_to_year)

Calculates the discount factor to be used for a time period `t`
using a fixed 'discount_rate`. There are two types of discounting
available, either discounting to the start of the time period
or calculating an approximate value for the average discount factor
over the whole time period (`type="avg"`).
"""
function discount(
    t::TimePeriod,
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    start_year = _to_year(_start_strat(t, ts), timeunit_to_year)
    duration_years = _to_year(duration(t), timeunit_to_year)

    multiplier = 1.0

    if type == "start"
        multiplier = discount_start(discount_rate, start_year)
    elseif type == "avg"
        multiplier = discount_avg(discount_rate, start_year, duration_years)
    end

    return multiplier
end

function discount(
    disc::Discounter,
    t::TimePeriod;
    type = "start",
    timeunit_to_year = 1.0,
)
    return discount(t, disc.ts, disc.discount_rate; type, timeunit_to_year)
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

function discount(
    sp::AbstractStrategicPeriod,
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    start_year = _to_year(_start_strat(sp, ts), timeunit_to_year)
    duration_years = _to_year(duration_strat(sp), timeunit_to_year)

    if type == "start"
        return discount_start(discount_rate, start_year)
    elseif type == "avg"
        return discount_avg(discount_rate, start_year, duration_years)
    end
end

"""
    objective_weight(t, time_struct, discount_rate; type, timeunit_to_year)

Returns an overall weight to be used for a time period `t`
in the objective function considering both discounting,
probability and possible multiplicity.
"""
function objective_weight(
    t::TimePeriod,
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    return probability(t) *
           discount(t, ts, discount_rate; type, timeunit_to_year) *
           multiple(t)
end

function objective_weight(t::TimePeriod, disc::Discounter; type = "start")
    return objective_weight(
        t,
        disc.ts,
        disc.discount_rate;
        type = type,
        timeunit_to_year = disc.timeunit_to_year,
    )
end

function objective_weight(
    sp::AbstractStrategicPeriod,
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    return discount(sp, ts, discount_rate; type, timeunit_to_year)
end

function objective_weight(
    sp::AbstractStrategicPeriod,
    disc::Discounter;
    type = "start",
)
    return objective_weight(
        sp,
        disc.ts,
        disc.discount_rate;
        type = type,
        timeunit_to_year = disc.timeunit_to_year,
    )
end
