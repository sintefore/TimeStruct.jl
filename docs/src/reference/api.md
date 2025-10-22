# [Interface for using `TimeStruct](@id api)

## [Available time structures](@id api-ts)

### [Abstract supertypes](@id api-ts-abstract)

```@docs
TimeStructure
```

### [Conecrete types](@id api-ts-con)

```@docs
SimpleTimes
CalendarTimes
OperationalScenarios
RepresentativePeriods
TwoLevel
TwoLevelTree
TreeNode
regular_tree
```

## [Properties of time structures](@id api-prop_ts)

```@docs
mult_scen
mult_repr
mult_strat
probability_scen
probability_branch
```

## [Iterating time structures](@id api-iter)

### [For individual time structures](@id api-iter-ts)

```@docs
repr_periods
opscenarios
strat_periods
strategic_periods
strategic_scenarios
```

### [Specialized iterators](@id api-iter-spec)

```@docs
withprev
withnext
chunk
chunk_duration
```

## [Properties of time periods](@id api-prop_per)

```@docs
duration
isfirst
multiple
multiple_strat
probability
start_oper_time
end_oper_time
```

## [Time profiles](@id api-prof)

```@docs
FixedProfile
OperationalProfile
RepresentativeProfile
ScenarioProfile
StrategicProfile
StrategicStochasticProfile
```

## [Discounting](@id api-disc)

### [Type](@id api-disc-type)

```@docs
Discounter
```

### [Functions](@id api-disc-type)

```@docs
discount
objective_weight
```
