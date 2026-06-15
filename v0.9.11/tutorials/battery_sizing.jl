# # Battery sizing

# This tutorial demonstrates how to formulate a battery sizing problem using the `TimeStruct` package
# in combination with `JuMP`.
# We start by defining the operational model of the battery, which includes the constraints and the
# objective function. Then, we extend the model to include the strategic decisions of the battery sizing.

# For this tutorial, we use the `HiGHS` solver for optimization:
using TimeStruct
using JuMP
using HiGHS

optimizer = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)

# ## Operational model

# We start by defining the operational model of the battery.
# The battery has a fixed capacity and can charge and discharge energy to cover
# a given demand profile. Additionally, the demand can be covered by purchasing
# energy from the spot market with a given price profile.
function create_operational(
    periods::TimeStructure,
    capacity,
    demand::TimeProfile,
    price::TimeProfile,
)
    model = Model()

    @variable(model, soc[periods] >= 0)         # State of charge of the battery
    @variable(model, charge[periods] >= 0)      # Energy charged to the battery
    @variable(model, discharge[periods] >= 0)   # Energy discharged from the battery
    @variable(model, spot[periods] >= 0)        # Energy purchased from the spot market

    for (prev, t) in withprev(periods)
        @constraint(model, soc[t] <= capacity)
        soc_prev = isnothing(prev) ? soc[last(periods)] : soc[prev]
        @constraint(model, soc[t] == soc_prev + charge[t] - discharge[t])
        @constraint(model, spot[t] + discharge[t] - charge[t] == demand[t])
    end

    @objective(model, Min, sum(multiple(t) * price[t] * spot[t] for t in periods))
    return model
end
# Note the use of the special iterator  [`withprev`](@ref) to iterate over the periods with the previous period,
# returning `nothing` for the first period. In this example we have opted to use a cyclic constraint for the state of charge,
# i.e. the state of charge of the last period is used as the initial state of charge for the first period.

# To test the model, we create a simple example with 24 hourly periods, a capacity of 20, a fixed demand of 5.0,
# and a time dependent price profile that varies sinusoidally over a day.
periods = SimpleTimes(24, 1)
capacity = 20
demand = FixedProfile(5.0)
price = OperationalProfile([1 + 0.3 * sin(i) for (i, t) in enumerate(periods)])

model = create_operational(periods, capacity, demand, price)
set_optimizer(model, optimizer)
optimize!(model)
println("Objective value: ", objective_value(model))

# ## Strategic model

# We now extend the operational model to include the strategic decisions of the battery sizing.
# For simplicity, we assume that the battery capacity can be chosen independently for each stragic period,
# e.g., by renting a battery of a given capacity for each strategic period.

# To simplify the process of defining the strategic model, we define helper functions to create the operational variables,
# constraints, and objective function.
function create_operational_variables(model, periods)
    @variable(model, soc[periods] >= 0)
    @variable(model, charge[periods] >= 0)
    @variable(model, discharge[periods] >= 0)
    @variable(model, spot[periods] >= 0)
end

function create_operational_constraints(model, periods, capacity, demand)
    soc, charge, discharge = model[:soc], model[:charge], model[:discharge]
    spot = model[:spot]
    for (prev, t) in withprev(periods)
        @constraint(model, soc[t] <= capacity)
        soc_prev = isnothing(prev) ? soc[last(periods)] : soc[prev]
        @constraint(model, soc[t] == soc_prev + charge[t] - discharge[t])
        @constraint(model, spot[t] + discharge[t] - charge[t] == demand[t])
    end
end

function create_operational_objective(model, periods, price)
    spot = model[:spot]
    el_cost = sum(multiple(t) * probability(t) * price[t] * spot[t] for t in periods)
    return el_cost
end
# Note the use of the [`multiple`](@ref) function to include the multiplier of each operational period for time
# structures where the operational periods do not cover the complete strategic periods and
# [`probability`](@ref) for periods that have an associated probability when using operational scenarios.

# We can now define the strategic model by creating a battery sizing decision for each strategic period.
# To obtain the strategic periods, we use the [`strat_periods`](@ref) iterator.
function create_strategic_model(
    periods::TimeStructure,
    price::TimeProfile,
    demand::TimeProfile,
    capex,
)
    model = Model()
    @variable(model, cap[strat_periods(periods)] >= 0)

    create_operational_variables(model, periods)
    for sp in strat_periods(periods)
        create_operational_constraints(model, sp, cap[sp], demand)
    end
    op_cost = create_operational_objective(model, periods, price)
    investment_cost = sum(cap[sp] * capex[sp] for sp in strat_periods(periods))
    @objective(model, Min, investment_cost + op_cost)
    return model
end
# Note that each strategic period can be iterated as a separate time structure and be
# used to define the operational constraints.

# To test the model, we create a simple example with 7 strategic periods of 24 hourly periods each
periods = TwoLevel(7, SimpleTimes(24, 1))
demand = StrategicProfile([5.0 + 0.5 * i for i in 1:7])
price = OperationalProfile([1 + 0.3 * sin(i) for i in 1:24])
capex = StrategicProfile([2 - 0.1 * i for i in 1:7])

model = create_strategic_model(periods, price, demand, capex)

set_optimizer(model, optimizer)
optimize!(model)
println("Objective value: ", objective_value(model))
println("Battery sizing: ", [value(model[:cap][sp]) for sp in strat_periods(periods)])

# ### Representative periods

# In large scale models, it is common to use representative periods to reduce the computational
# burden by aggregating the time series involved and use these to represent a larger
# share of the planning period. With `TimeStruct`, we can create constraints
# separately for each representative period by using the [`repr_periods`](@ref) iterator.
function create_strat_repr_model(periods, price, demand, capex)
    model = Model()
    @variable(model, cap[strat_periods(periods)] >= 0)

    create_operational_variables(model, periods)
    for sp in strat_periods(periods)
        for rp in repr_periods(sp)
            create_operational_constraints(model, rp, cap[sp], demand)
        end
    end

    op_cost = create_operational_objective(model, periods, price)
    investment_cost = sum(cap[sp] * capex[sp] for sp in strat_periods(periods))
    @objective(model, Min, investment_cost + op_cost)
    return model
end

# Setting up the model with representative periods requires defining the representative periods
# and the representative price profile.
periods = TwoLevel(
    5,
    1,
    RepresentativePeriods(8760, [0.3, 0.2, 0.4, 0.1], SimpleTimes(24, 1));
    op_per_strat = 8760,
)
repr_price = RepresentativeProfile([0.9 * price, 1.1 * price, 0.8 * price, 1.2 * price])
# In this example, we use 5 strategic periods of length 1 year each.
# Each strategic period is represented by 4 representative periods of 24 hours each.
# Note the use of the parameter `op_per_strat` to define the number of operational periods per strategic period.

model = create_strat_repr_model(periods, repr_price, demand, capex)
set_optimizer(model, optimizer)
optimize!(model)
println("Objective value: ", objective_value(model))
println("Battery sizing: ", [value(model[:cap][sp]) for sp in strat_periods(periods)])

# ### Operational scenarios

# Finally, we can extend the model to include operational scenarios to account for operational uncertainty in
# the battery sizing problem. Typically, the spot prices are uncertain and can be modeled as a set of scenarios
# with a specified probability for each scenario.
function create_strat_repr_scen_model(periods, price, demand, capex)
    model = Model()
    @variable(model, cap[strat_periods(periods)] >= 0)

    create_operational_variables(model, periods)
    for sp in strat_periods(periods)
        for rp in repr_periods(sp)
            for sc in opscenarios(rp)
                create_operational_constraints(model, sc, cap[sp], demand)
            end
        end
    end
    op_cost = create_operational_objective(model, periods, price)
    investment_cost = sum(cap[sp] * capex[sp] for sp in strat_periods(periods))
    @objective(model, Min, investment_cost + op_cost)
    return model
end
# The only difference in the model is the use of the [`opscenarios`](@ref) iterator to iterate over the operational scenarios.

# The time structure is similar to the previous example, but we now include 10 operational scenarios for each representative period.
periods = TwoLevel(
    5,
    1,
    RepresentativePeriods(
        8760,
        [0.3, 0.2, 0.4, 0.1],
        OperationalScenarios(10, SimpleTimes(24, 1)),
    );
    op_per_strat = 8760,
)

price = RepresentativeProfile([
    0.9 * ScenarioProfile([price + 0.1 * rand() for sc in 1:10]),
    1.1 * ScenarioProfile([price + 0.2 * rand() for sc in 1:10]),
    0.8 * ScenarioProfile([price + 0.05 * rand() for sc in 1:10]),
    1.2 * ScenarioProfile([price + 0.08 * rand() for sc in 1:10]),
])

model = create_strat_repr_scen_model(periods, price, demand, capex)
set_optimizer(model, optimizer)
optimize!(model)
println("Objective value: ", objective_value(model))
println("Battery sizing: ", [value(model[:cap][sp]) for sp in strat_periods(periods)])
