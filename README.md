# TimeStructures.jl

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Time Structures to facilitate modelling with different (multilevel) time structures. Note that this package is experimental/proof-of-concept. Expect breaking changes.

# Usage

```julia
using TimeStructures

uniform_day = UniformTimes(1, 24, 1) # 24 hours/day
uniform_year = UniformTwoLevel(1, 365, 1, uniform_day) # 365 days

length(uniform_year) # 8760 (hours in one year)

# Properties for easy indexing and constraints (example below)
[t.idx for t ∈ first(uniform_year, 2)]      # [(1, 1), (1, 2)]
[t.duration for t ∈ first(uniform_year, 2)] # [1, 1]

# Create constraints with JuMP something like this:
for t ∈ uniform_year
    @constraint(m, my_var[t.idx] <= val_per_time * t.duration)
end

# Get operational periods by strategic periods:
for 𝒯ⁱⁿᵛ ∈ strategic_periods(uniform_year)
    define(m, Node(), 𝒯ⁱⁿᵛ)
end

𝒯ⁱⁿᵛ = first(strategic_periods(uniform_year))
length(𝒯ⁱⁿᵛ) # 24

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

TimeStructures was funded by the Norwegian Research Council in the project Clean Export, project number ###