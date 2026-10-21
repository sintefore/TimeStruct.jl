# # Chance-constrained emissions

# This tutorial shows how [`scenario_paths`](@ref) can be used to formulate a chance
# constraint on the annual emissions of an energy system. The year is represented by two
# representative days, each with several weather years as operational scenarios. A chance
# constraint requires that the emission cap holds with a given probability. This requires a
# definition of the annual emissions in each outcome. The scenario paths provide this by
# making explicit which scenarios of the different representative periods belong together.

using TimeStruct
using JuMP
using HiGHS

# ## Time structure

# A year is represented by a winter day and a summer day with equal shares. Each day has
# five operational scenarios corresponding to five equally likely weather years. Weather
# year `s` is the same year in both representative periods, which is specified through a
# [`DiagonalPairing`](@ref):
n_years = 5
day = SimpleTimes(24, 1)
periods = RepresentativePeriods(
    8760,
    [0.5, 0.5],
    [OperationalScenarios(n_years, day), OperationalScenarios(n_years, day)];
    pairing = DiagonalPairing(),
)

# Each scenario path corresponds to one weather year through both representative periods:
paths = scenario_paths(periods)
probability.(paths)

# ## Data

# The wind capacity factors differ between the seasons and the weather years. Weather year 5
# is a calm year:
wind_level = [
    0.45 0.40 0.35 0.30 0.15   # winter
    0.30 0.28 0.25 0.20 0.10   # summer
]
function wind_cf(rp, s)
    return [clamp(wind_level[rp, s] * (1 + 0.5 * sin(2π * h / 24)), 0, 1) for h in 1:24]
end
wind = RepresentativeProfile([
    ScenarioProfile([OperationalProfile(wind_cf(rp, s)) for s in 1:n_years]) for rp in 1:2
])
demand = RepresentativeProfile([FixedProfile(100.0), FixedProfile(70.0)])

inv_cost = Dict(:wind => 120_000.0, :gas => 60_000.0)  # €/MW per year
fuel_cost = 60.0                                       # €/MWh
emission_factor = 0.4                                  # t CO2/MWh
emission_cap = 120_000.0                               # t CO2 per year
ε = 0.2;                                               # allowed probability of violation

# The annual value of an hourly quantity along a path sums over the time periods of the
# path. The function [`multiple`](@ref) scales a representative day to its share of the
# year, while [`duration`](@ref) gives the length of the time period:
annual(x, path) = sum(x[t] * duration(t) * multiple(t) for t in path)

# ## Model

# The model invests in wind and gas capacity and dispatches them to cover the demand. The
# operational costs are weighted with the probabilities of the operational scenarios through
# [`probability`](@ref) of the time periods. The annual emissions are computed for each
# scenario path. The keyword `method` selects how the emission cap is enforced.
function build_model(periods, method)
    model = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false))

    @variable(model, cap_wind >= 0)
    @variable(model, cap_gas >= 0)
    @variable(model, gen_wind[periods] >= 0)
    @variable(model, gen_gas[periods] >= 0)
    @constraint(model, [t in periods], gen_wind[t] <= wind[t] * cap_wind)
    @constraint(model, [t in periods], gen_gas[t] <= cap_gas)
    @constraint(model, [t in periods], gen_wind[t] + gen_gas[t] == demand[t])

    @objective(
        model,
        Min,
        inv_cost[:wind] * cap_wind +
        inv_cost[:gas] * cap_gas +
        sum(
            probability(t) * multiple(t) * duration(t) * fuel_cost * gen_gas[t] for
            t in periods
        )
    )

    paths = scenario_paths(periods)
    @expression(
        model,
        emissions[k in eachindex(paths)],
        emission_factor * annual(gen_gas, paths[k])
    )
    add_emission_constraint!(model, Val(method), paths)

    optimize!(model)
    @assert is_solved_and_feasible(model)
    return model
end

# ### Expected emissions

# As a reference, the expected annual emissions are constrained. The expectation uses the
# probabilities of the scenario paths:
function add_emission_constraint!(model, ::Val{:expected}, paths)
    emissions = model[:emissions]
    @constraint(
        model,
        sum(probability(p) * emissions[k] for (k, p) in enumerate(paths)) <= emission_cap
    )
end

# ### Chance constraint

# The chance constraint requires that the probability of the annual emissions exceeding the
# cap is at most `ε`:
#
# ```math
# \mathbb{P}(E_k \leq \text{cap}) \geq 1 - \varepsilon
# ```
#
# It is formulated with a binary variable `z[k]` for each path. If `z[k] = 1`, the emissions
# of path `k` may exceed the cap. The total probability of these paths is limited by `ε`. The
# big-M constant is the largest possible violation, which corresponds to covering all demand
# with gas:
function add_emission_constraint!(model, ::Val{:chance}, paths)
    emissions = model[:emissions]
    @variable(model, z[eachindex(paths)], Bin)
    for (k, path) in enumerate(paths)
        max_emissions = emission_factor * annual(Dict(t => demand[t] for t in path), path)
        @constraint(
            model,
            emissions[k] <= emission_cap + (max_emissions - emission_cap) * z[k]
        )
    end
    @constraint(model, sum(probability(p) * z[k] for (k, p) in enumerate(paths)) <= ε)
end

# ### Conditional value-at-risk

# A convex and conservative approximation of the chance constraint limits the conditional
# value-at-risk (CVaR) of the emissions, that is, the expected emissions of the worst
# outcomes with total probability `ε`:
function add_emission_constraint!(model, ::Val{:cvar}, paths)
    emissions = model[:emissions]
    @variable(model, η)
    @variable(model, u[eachindex(paths)] >= 0)
    @constraint(model, [k in eachindex(paths)], u[k] >= emissions[k] - η)
    @constraint(
        model,
        η + sum(probability(p) * u[k] for (k, p) in enumerate(paths)) / ε <= emission_cap
    )
end

# ## Results

# We solve the model with the three formulations and compare the investments, the annual
# emissions of each weather year, and the probability that the emission cap is violated:
for method in (:expected, :chance, :cvar)
    model = build_model(periods, method)
    emissions = value.(model[:emissions])
    violation = sum(
        probability(p) for (k, p) in enumerate(paths) if emissions[k] > emission_cap + 1e-3;
        init = 0.0,
    )
    println(
        rpad(method, 9),
        "cost: ",
        round(objective_value(model) / 1e6; digits = 2),
        " M€, wind: ",
        round(value(model[:cap_wind]); digits = 1),
        " MW, gas: ",
        round(value(model[:cap_gas]); digits = 1),
        " MW, emissions: ",
        round.(Int, emissions ./ 1e3),
        " kt, P(violation): ",
        violation,
    )
end

# Constraining the expected emissions results in two of the five weather years exceeding the
# cap. The chance constraint only allows the calm weather year to exceed the cap, as its
# probability equals `ε`, at a small increase in cost. With `ε` equal to the probability of
# a single path, the CVaR constraint corresponds to requiring that the worst weather year
# satisfies the cap, which requires a significantly larger wind capacity.

# ## Remarks

# - The two probabilities are kept apart. The operational costs use the probabilities of the
#   operational scenarios, while the chance constraint uses the probabilities of the paths.
#   With a consistent pairing, such as the `DiagonalPairing`, both describe the same
#   probability distribution, see [Consistent probabilities](@ref man-iter-paths-prob).
# - The pairing determines the meaning of the chance constraint. Pairing all combinations
#   of the scenarios through a [`ScenarioPairing`](@ref) would also count, *e.g.*, a calm
#   winter combined with a windy summer as an outcome.
# - With `n` equally likely paths, `ε` only has an effect in steps of `1/n`. More paths give
#   a finer resolution, at the cost of one binary variable per path.
# - In a [`TwoLevel`](@ref) time structure, `multiple` also includes the scaling of the
#   strategic period. The emissions should then be formulated for each strategic period and
#   the scaling verified.
