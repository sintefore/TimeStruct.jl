DiscPeriods = Union{TimePeriod,AbstractOperationalScenario,AbstractRepresentativePeriod}

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

_start_strat(sp::AbstractStrategicPeriod, ts::TimeStructure{T}) where {T} = zero(T)
function _start_strat(sp::AbstractStrategicPeriod, ts::TwoLevel{S}) where {S}
    return sum(duration_strat(spp) for spp in strat_periods(ts) if spp < sp; init = zero(S))
end
function _start_strat(sp::StratNode, ts::TwoLevelTree{S}) where {S}
    start = zero(S)
    node = _parent(sp)
    while !isnothing(node)
        start += duration_strat(node)
        node = _parent(node)
    end
    return start
end
_start_strat(t::DiscPeriods, ts::TimeStructure) = _start_strat(_sp_period(t, ts), ts)

_sp_period(sp::AbstractStrategicPeriod, _::TimeStructure) = sp
function _sp_period(t::DiscPeriods, ts::TimeStructure)
    for sp in strat_periods(ts)
        if _strat_per(sp) == _strat_per(t)
            return sp
        end
    end
    @error("Time period not part of any strategic period")
end
function _sp_period(t::TreePeriod, tree::TwoLevelTree)
    for sp in strat_periods(tree)
        if _strat_per(sp) == _strat_per(t) && _branch(sp) == _branch(t)
            return sp
        end
    end
    @error("Tree period not part of any strategic node")
end

function _to_year(start, timeunit_to_year)
    return start * timeunit_to_year
end

"""
    discount(t, time_struct, discount_rate; type, timeunit_to_year)

Calculates the discount factor to be used for a time period `t`
using a fixed 'discount_rate`. There are two types of discounting
available, either discounting to the start of the strategic period
containing the time period (`type="start"`) or calculating an approximate
value for the average discount factor over the whole strategic period.
The average can be calculated either as a continuous average (`type="avg"`) or
as a discrete average that discounts to the start of each year (`type="avg_year"`).
The `timeunit_to_year` parameter is used to convert the time units of
strategic periods in the time structure to years (default value = 1.0).
"""
function discount(
    t::Union{TimePeriod,TimeStructurePeriod},
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    sp = _sp_period(t, ts)
    discount_factor = 1.0
    if discount_rate > 0
        start_year = _to_year(_start_strat(sp, ts), timeunit_to_year)
        duration_years = _to_year(duration_strat(sp), timeunit_to_year)
        if type == "start"
            discount_factor = discount_start(discount_rate, start_year)
        elseif type == "avg"
            discount_factor = discount_avg(discount_rate, start_year, duration_years)
        elseif type == "avg_year"
            discount_factor = discount_avg_year(discount_rate, start_year, duration_years)
        end
    end
    return discount_factor
end
function discount(
    disc::Discounter,
    t::Union{TimePeriod,TimeStructurePeriod};
    type = "start",
)
    ts = disc.ts
    timeunit_to_year = disc.timeunit_to_year
    return discount(_sp_period(t, ts), ts, disc.discount_rate; type, timeunit_to_year)
end

function discount_avg(discount_rate, start_year, duration_years)
    δ = 1 / (1 + discount_rate)
    return (δ^start_year - δ^(start_year + duration_years)) / log(1 + discount_rate) /
           duration_years
end

function discount_avg_year(discount_rate, start_year, duration_years)
    δ = 1 / (1 + discount_rate)
    return sum(δ^(start_year + i) for i in 0:(duration_years-1)) / duration_years
end

function discount_start(discount_rate, start_year)
    δ = 1 / (1 + discount_rate)
    return δ^start_year
end

"""
    objective_weight(t, time_struct, discount_rate; type, timeunit_to_year)

Returns an overall weight to be used for a time period `t`
in the objective function considering both discounting,
probability and possible multiplicity. There are two types of discounting
available, either discounting to the start of the strategic period
containing the time period (`type="start"`) or calculating an approximate
value for the average discount factor over the whole strategic period.
The average can be calculated either as a continuous average (`type="avg"`) or
as a discrete average that discounts to the start of each year (`type="avg_year"`).
The `timeunit_to_year` parameter is used to convert the time units of
strategic periods in the time structure to years (default value = 1.0).
"""
function objective_weight(
    t::Union{TimePeriod,TimeStructurePeriod},
    ts::TimeStructure,
    discount_rate;
    type = "start",
    timeunit_to_year = 1.0,
)
    return _objective_value(t, ts, discount_rate, type, timeunit_to_year)
end
function objective_weight(
    t::Union{TimePeriod,TimeStructurePeriod},
    disc::Discounter;
    type = "start",
)
    timeunit_to_year = disc.timeunit_to_year
    return objective_weight(t, disc.ts, disc.discount_rate; type = type, timeunit_to_year)
end

function _objective_value(
    t::DiscPeriods,
    ts::TimeStructure,
    discount_rate,
    type,
    timeunit_to_year,
)
    return probability(t) *
           discount(t, ts, discount_rate; type, timeunit_to_year) *
           multiple(t)
end
function _objective_value(
    t::AbstractStrategicPeriod,
    ts::TimeStructure,
    discount_rate,
    type,
    timeunit_to_year,
)
    return discount(t, ts, discount_rate; type, timeunit_to_year)
end
