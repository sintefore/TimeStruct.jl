# # Basic Usage

# This tutorial demonstrates the basic usage of generating flexible optimization models using
# the `TimeStruct` package in combination with `JuMP`.
using TimeStruct, JuMP

# ## Time structures and time profiles

# We start by defining a simple time structure with 4 periods of varying duration
simple = SimpleTimes(4, [1, 2, 3, 2])

# The time structure can be iterated over to access the periods and the duration can
# be queried for each period.
print([duration(t) for t in simple])

# The time periods can be used for lookups in time profiles of various types. For example,
# a fixed cost profile can be defined with a constant cost of 2.0 for all periods.
cost_fixed = FixedProfile(2.0)
print([cost_fixed[t] for t in simple])

# A dynamic cost profile can be defined with varying costs for each period.
cost_dynamic = OperationalProfile([1.0, 2.0, 3.0, 2.0])
print([cost_dynamic[t] for t in simple])

# One of the main purposes of the `TimeStruct` package is to facilitate the modeling of
# optimization problems with multiple time horizons. For this, we define a two-level time structure
# with 2 strategic periods, each with the same operational time structure.
two_level = TwoLevel(2, simple)
nper = length(two_level)

# We can also define a strategic cost profile with different cost profiles for each strategic period.
cost_strategic = StrategicProfile([FixedProfile(2.0), FixedProfile(3.0)])
print([cost_strategic[t] for t in two_level])

# ## Optimization modeling

# We are now ready to create a generic optimization model based on a given time structure and cost profile.
# This basic model illustrates the creation of optimization variables defined over the time structure,
# as well as constraints and an objective function based on the cost profile.
function create_model_1(periods::TimeStructure, cost::TimeProfile)
    m = Model()
    @variable(m, x[periods])
    @constraint(m, sum(x[t] for t in periods) <= 1)
    @objective(m, Max, sum(cost[t] * x[t] for t in periods))
    return m
end

# Using the simple time structure and fixed cost profile, we can create a first realization of the model.
model = create_model_1(simple, cost_fixed)
latex_formulation(model)

# Exchanging the fixed cost profile with the dynamic cost profile will change the model formulation
# to reflect the varying costs.
model = create_model_1(simple, cost_dynamic)
latex_formulation(model)

# Time profiles are not connected to the time structure, so we can use the same cost profile
# for different time structures. This allows for a flexible modeling approach, e.g., during
# testing and model development.
simple_test = SimpleTimes([1])
model = create_model_1(simple_test, cost_dynamic)
latex_formulation(model)

# ## Multiple horizon modeling

# In a multi horizon optimization problem, there are typically constraints
# that are defined for each strategic period separately. To illustrate this, we create
# a model with a separate constraint for each strategic period using
# the `strat_periods` function to iterate over the strategic periods of the time structure.
function create_model_2(periods::TimeStructure, cost::TimeProfile)
    m = Model()
    @variable(m, x[periods])
    for sp in strat_periods(periods)
        @constraint(m, sum(x[t] for t in sp) <= 1)
    end
    @objective(m, Max, sum(cost[t] * x[t] for t in periods))

    return m
end

# Creating a strategic model with a fixed cost profile, we see that
# we get a separate constraint for each of the two strategic periods.
model = create_model_2(two_level, cost_fixed)
latex_formulation(model)

# Using a strategic cost profile will differentiate the costs for each strategic period.
model = create_model_2(two_level, cost_strategic)
latex_formulation(model)

# A general design principle of the `TimeStruct` package is to allow for
# simpler time structures, even in models that have separate modeling, e.g. for
# strategic periods. This is illustrated here by using the `simple` time structure
# in the strategic model. In this case, iterating over the strategic periods will
# result in a single strategic period that is equal to the original time structure.
model = create_model_2(simple, cost_fixed)
latex_formulation(model)
