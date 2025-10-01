DiscPeriods = Union{TimePeriod,AbstractOperationalScenario,AbstractRepresentativePeriod}

"""
    Discounter(discount_rate, ts::TimeStructure)
    Discounter(discount_rate, timeunit_to_year, ts::TimeStructure)

Structure to hold discount information to be used for a time structure `ts`. The
`discount_rate` is an absolute discount rate while the parameter `timeunit_to_year` is used
convert the time units of strategic periods in the time structure to years (default value = 1.0).

As an example, consider the following time structure:

```julia
# Modelling of a day with hourly resolution for 50 years with a resolution of 5 years
periods = TwoLevel(10, 5 * 8760, SimpleTimes(24, 1))

# The parameter `timeunit_to_year` must in this case be 1 year / 8760 h
disc = Discounter(0.04, 1 / 8760, periods)
```
"""
struct Discounter
    discount_rate::Any
    timeunit_to_year::Any
    ts::TimeStructure
end
Discounter(discount_rate, ts::TimeStructure) = Discounter(discount_rate, 1.0, ts)

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

_sp_period(sp::AbstractStrategicPeriod, _::TimeStructure) = sp
function _sp_period(t::DiscPeriods, ts::TimeStructure)
    sps = collect(strat_periods(ts))
    per = findfirst(sp -> _strat_per(sp) == _strat_per(t), sps)
    isnothing(per) && throw(ErrorException("Time period not part of any strategic period"))
    return sps[per]
end
function _sp_period(t::TreePeriod, tree::TwoLevelTree)
    sps = collect(strat_periods(tree))
    per = findfirst(sp -> _strat_per(sp) == _strat_per(t) && _branch(sp) == _branch(t), sps)
    isnothing(per) && throw(ErrorException("Tree period not part of any strategic node"))
    return sps[per]
end

function _to_year(start, timeunit_to_year)
    return start * timeunit_to_year
end

"""
    discount(t::Union{TimePeriod,TimeStructurePeriod}, time_struct::TimeStructure, discount_rate; type = "start", timeunit_to_year=1.0)
    discount(disc::Discounter, t::Union{TimePeriod,TimeStructurePeriod}; type = "start")

Calculates the discount factor to be used for a time period `t` using a fixed `discount_rate`.
The function can be either called using a [`Discounter`](@ref) type or by specifying the
parameters (time structure `ts`, `discount_rate` and potentially `timeunit_to_year`) directly.

There are two types of discounting available:

1. Discounting to the start of the strategic period containing the time period:\n
   This can be achieved through specifying `type="start"`. It is useful for investment costs
2. Discounting to the average of the over the whole strategic period:\n
   The average can be calculated either as a continuous average (`type="avg"`) or as a
   discrete average that discounts to the start of each year (`type="avg_year"`). Average
   discounting is useful for operational costs.

The `timeunit_to_year` parameter is used to convert the time units of strategic periods in
the time structure to years (default value = 1.0).

!!! tip "Comparison with `objective_weight`"
    Both [`objective_weight`](@ref) and `discount` can serve similar purposes. Compared to
    [`objective_weight`](@ref), `discount` only calculates the discount factor for a given
    time period. If `t` is an [`AbstractStrategicPeriod`](@ref), both are
    equivalent.
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
    return discount(t, ts, disc.discount_rate; type, timeunit_to_year)
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
    objective_weight(t::Union{TimePeriod,TimeStructurePeriod}, ts::TimeStructure, discount_rate; type = "start", timeunit_to_year = 1.0)
    objective_weight(t::Union{TimePeriod,TimeStructurePeriod}, disc::Discounter; type = "start")


Calculates the overall objective weight for a time period `t` using a fixed `discount_rate`.
The weight consideres both discounting, the probability and potential multiplicity of `t`
The function can be either called using a [`Discounter`](@ref) type or by specifying the
parameters (time structure `ts`, `discount_rate` and potentially `timeunit_to_year`) directly.

There are two types of discounting available:

1. Discounting to the start of the strategic period containing the time period:\n
   This can be achieved through specifying `type="start"`. It is useful for investment costs
2. Discounting to the average of the over the whole strategic period:\n
   The average can be calculated either as a continuous average (`type="avg"`) or as a
   discrete average that discounts to the start of each year (`type="avg_year"`). Average
   discounting is useful for operational costs.

The `timeunit_to_year` parameter is used to convert the time units of strategic periods in
the time structure to years (default value = 1.0).

!!! tip "Comparison with `discount`"
    Both [`discount`](@ref) and `objective_weight` can serve similar purposes. Compared to
    [`discount`](@ref), `objective_weight` includes as well the probablity and multiplicity
    of a given time period. If `t` is an [`AbstractStrategicPeriod`](@ref), both are
    equivalent.
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
