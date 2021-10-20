# TimeStructures.jl

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Time Structures to facilitate modelling with different (multilevel) time structures. Note that this package is experimental/proof-of-concept. Expect breaking changes.

## Usage

```julia
using TimeStructures

uniform_day = SimpleTimes(24, 1) # 24 hours/day
uniform_year = TwoLevel(365, 8760, uniform_day) # 365 days

length(uniform_year) # 8760 (hours in one year)

# Properties for easy indexing and constraints (example below)
[t for t ∈ first(uniform_year, 2)]
# 2-element Vector{OperationalPeriod}:
#  t1_1
#  t1_2
[t.duration for t ∈ first(uniform_year, 2)] # [1, 1]

val_per_time = FixedProfile(0.2)

# Create constraints with JuMP something like this:
for t ∈ uniform_year
    @constraint(m, my_var[t] <= val_per_time[t] * t.duration)
end

# Get operational periods by strategic periods:
for 𝒯ⁱⁿᵛ ∈ strategic_periods(uniform_year)
    define(m, Node(), 𝒯ⁱⁿᵛ)
end

𝒯ⁱⁿᵛ = first(strategic_periods(uniform_year))
length(𝒯ⁱⁿᵛ) # 24

```

## Stochastic optimization

A simple example illustrating the use of the OperationalScenarios time structure to model a
simple two stage stochastic optimization problem.

```julia

using JuMP
using TimeStructures

𝒯 = OperationalScenarios(5, SimpleTimes(10,1))
𝒮 = scenarios(T)

model = Model()

ℐ = 1:5
@variable(model, x[ℐ, 𝒯])
@variable(model, y[ℐ], Bin)
@variable(model, npv)
@variable(model, μ[𝒮])

for i ∈ ℐ, t ∈ 𝒯 
    @constraint(model, x[i,t] <= y[i])
end

@constraint(model, sum(y[i] for i ∈ ℐ) <= 2)

for scen ∈ S
    @constraint(model,  μ[scen] == sum(rand() * x[i,t] for i ∈ ℐ for t ∈ scen))
end
@constraint(model, npv == sum(probability(s) * μ[s] for s ∈ 𝒮))
```

## TODO

* Discuss default duration of period, unit?
* Naming/API improvements
* get total duration, start/end time of a given time period"
* last period(?)
* More examples
  * 'three-level': year, season, week
  * Two-stage equiprobable stochastic
  * Two-stage stochastic with probabilities
  * Multi-stage, uniform branching, etc..
  * Multi-horizon


## Funding

TimeStructures was funded by the Norwegian Research Council in the project Clean Export, project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)