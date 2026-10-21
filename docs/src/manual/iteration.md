# [Iteration utilities](@id man-iter)

## [Basic iteration](@id man-iter-basic)

All time structures are iterable over their operational time periods:
```@repl ts
using TimeStruct

function iterate_ex(periods::TimeStructure)
    for t in periods
        println(t)
    end
end
```

## [Iteration with previous](@id man-iter-prev)

In many settings, e.g., tracking of storage, it is convenient to have access to the previous time period. By using the custom iterator [`withprev`](@ref), it is possible to return both the previous and current time period as a tuple when iterating:
```@repl ts
using TimeStruct
periods = SimpleTimes(5, 1);
collect(withprev(periods))
```

A variant of this is the [`withnext`](@ref) iterator that returns
the current and next period (or `nothing` if none).

## [Iteration with chunks of time periods](@id man-iter-chunk)

Sometimes it is convenient to iterate through the time periods as chunks of a fixed number of periods or minimum duration, e.g., in production planning with minimum production runs. To simplify this process, there are several iterator wrappers that allow this kind of iteration pattern.

The [`chunk`](@ref) function iterates through a time structure, returning subsequences of length at most `n` starting at each time period.
```@repl ts
periods = SimpleTimes(5,1)
collect(collect(ts) for ts in chunk(periods, 3))
```

This wrapper can be used for, e.g., modeling of startup processes with a minimum uptime. The following example shows how this can be implemented as part of a JuMP model:
```@example
using JuMP, TimeStruct

periods = SimpleTimes(5,1)

m = Model()
@variable(m, startup[periods], Bin)
@variable(m, shutdown[periods], Bin)

for ts in chunk(periods, 3)
    @constraint(m, sum(shutdown[t] for t in ts) <= 3 * (1 - startup[first(ts)]))
end

for cref in all_constraints(m, AffExpr, MOI.LessThan{Float64}) # hide
    println(constraint_string(MIME("text/plain"), cref; in_math_mode = true)) # hide
end # hide
```
Similarly, if modeling startup decisions with a minimum downtime, it is possible to reverse the original time periods and then chunk:
```@example
using JuMP, TimeStruct # hide
periods = SimpleTimes(5,1) # hide

m = Model() # hide
@variable(m, startup[periods], Bin) # hide
@variable(m, shutdown[periods], Bin) # hide
for ts in chunk(Iterators.reverse(periods), 3)
    @constraint(m, sum(shutdown[t] for t in ts) <= 3 * (1 - startup[first(ts)]))
end

for cref in all_constraints(m, AffExpr, MOI.LessThan{Float64}) # hide
    println(constraint_string(MIME("text/plain"), cref; in_math_mode = true)) # hide
end # hide
```

It is also possible to get cyclic behavior by setting the `cyclic` argument to `true`.
If reaching the end before the required number of time periods, the chunk will continue from the first time period.
```@example
using JuMP, TimeStruct # hide
periods = SimpleTimes(5,1) # hide

m = Model() # hide
@variable(m, startup[periods], Bin) # hide
@variable(m, shutdown[periods], Bin) # hide
for ts in chunk(periods, 3; cyclic = true)
    @constraint(m, sum(shutdown[t] for t in ts) <= 3 * (1 - startup[first(ts)]))
end
for cref in all_constraints(m, AffExpr, MOI.LessThan{Float64}) # hide
    println(constraint_string(MIME("text/plain"), cref; in_math_mode = true)) # hide
end # hide
```

## [Chunks based on duration](@id man-iter-chunk_dur)

If working with a time structure that has varying duration for its time periods, it can be more convenient to use chunks based on their combined duration.

The [`chunk_duration`](@ref) function iterates through a time structure, returning subsequences with a duration of at least `dur` starting at each time period.
```@repl ts
periods = SimpleTimes(5,[1, 2, 1, 1.5, 0.5, 2])
collect(collect(ts) for ts in chunk_duration(periods, 3))
```

## [Indexing of operational time structures](@id man-iter-index)

It is possible to use indices for operational time structures, either directly using [`SimpleTimes`](@ref) or [`CalendarTimes`](@ref), or by accessing an operational scenario.

```@repl ts
periods = TwoLevel(3, 100, SimpleTimes(10,1));

scenario = first(opscenarios(periods))
scenario[3]
```

## [Scenario paths across representative periods](@id man-iter-paths)

When [`OperationalScenarios`](@ref) are used within [`RepresentativePeriods`](@ref), each representative period has its own set of scenarios. Iterating with [`opscenarios`](@ref) gives the scenarios of each representative period separately. It does not say how the scenarios of different representative periods belong together. Constraints that span all representative periods for a given scenario need this coupling, for example an annual budget or a storage level linked across representative periods.

The function [`scenario_paths`](@ref) makes this coupling explicit. It returns joint scenario paths, where each path selects one operational scenario per representative period and has an id and a probability. The paths are specified by a [`ScenarioPairing`](@ref), a list of paths with probabilities, or generated by a [`PairingMethod`](@ref). The only method included in `TimeStruct` is [`DiagonalPairing`](@ref), which uses scenario `k` in all representative periods (coherent annual paths):

```@repl ts
oscs = OperationalScenarios([SimpleTimes(2, 1), SimpleTimes(2, 1)], [0.6, 0.4]);
periods = RepresentativePeriods(2, 8760, oscs);

paths = scenario_paths(periods, DiagonalPairing())
paths = scenario_paths(periods, ScenarioPairing([1 1; 2 2; 1 2; 2 1], [0.4, 0.2, 0.2, 0.2]))
probability.(paths)
collect(paths[3])
```

Other ways of combining the scenarios, such as all combinations of scenarios or sampled paths, are scenario generation methods and not part of `TimeStruct`. They are implemented as subtypes of [`PairingMethod`](@ref) in other packages, and [`generate_pairing`](@ref) turns a method into a `ScenarioPairing`. The function [`scenario_probabilities`](@ref) provides the scenario probabilities of each representative period as input. The following example shows a method for all combinations of the scenarios:

```@repl ts
struct AllCombinations <: PairingMethod end
function TimeStruct._paths(::AllCombinations, probs)
    paths = [[s1, s2] for s1 in eachindex(probs[1]) for s2 in eachindex(probs[2])]
    return paths, [probs[1][s1] * probs[2][s2] for (s1, s2) in paths]
end
generate_pairing(AllCombinations(), periods)
scenario_paths(periods, AllCombinations())
```

The pairing is a property of the scenario data, so it can be stored in the time structure through the keyword argument `pairing` of [`RepresentativePeriods`](@ref). A `PairingMethod` is then resolved once, and the resulting `ScenarioPairing` is validated and stored, so that all later calls use the same paths. [`scenario_paths`](@ref) uses the stored pairing when called without a pairing. Providing a pairing explicitly overrides the stored one, for example to test how sensitive the results are to the assumed coupling:

```@repl ts
periods = RepresentativePeriods(2, 8760, oscs; pairing = DiagonalPairing());
periods.pairing
scenario_paths(periods)
scenario_paths(periods, AllCombinations())
```

If no pairing is stored and the time structure has more than one representative period, calling `scenario_paths(periods)` throws an error. This keeps the coupling from being chosen silently. In a [`TwoLevel`](@ref) or [`TwoLevelTree`](@ref) structure, the pairing stored in each strategic period's representative periods is used.

### [Consistent probabilities](@id man-iter-paths-prob)

The path probabilities are *consistent* with the operational scenarios if, for each representative period, the probabilities of the paths that use a scenario sum to the probability of that scenario. Otherwise, a model that weights operational costs with the scenario probabilities and path-based terms with the path probabilities uses two different probability distributions. The function [`path_marginals`](@ref) returns these sums, so they can be compared with the scenario probabilities.

[`DiagonalPairing`](@ref) is always consistent. For a [`ScenarioPairing`](@ref), the consistency is checked and results in a warning by default. The keyword `check_marginals` changes this to an error (`:error`) or no check (`:none`).

If the scenario data are joint paths, *e.g.*, weighted weather years, the path probabilities are the primary data. In this case, the keyword argument `scenario_probability = :from_pairing` of [`RepresentativePeriods`](@ref) sets the probability of each operational scenario to the sum of the probabilities of the paths using it. The probabilities are then consistent by construction:

```@repl ts
oscs3 = OperationalScenarios(3, SimpleTimes(2, 1));
periods3 = RepresentativePeriods(
    2,
    8760,
    oscs3;
    pairing = ScenarioPairing([1 1; 2 2; 1 2], [0.5, 0.3, 0.2]),
    scenario_probability = :from_pairing,
);
scenario_probabilities(periods3)
path_marginals(periods3)
```

The scenario that is not part of any path gets zero probability, which results in a warning.

### [Using scenario paths](@id man-iter-paths-use)

The time periods of a path are the same periods as those of the time structure, so they can index variables and time profiles directly. The following example sets an annual limit on usage that must hold for each path:
```julia
for path in scenario_paths(periods)
    @constraint(m, sum(use[t] * duration(t) * multiple(t) for t in path) <= annual_limit)
end
```

!!! note
    The [`probability`](@ref) of a time period is the probability of its operational scenario. Use `probability(path)` to get the probability of the path.

As each path has a probability, constraints on the distribution of the outcomes can be formulated as well. The tutorial [Chance-constrained emissions](@ref) shows how to require that an annual emission cap holds with a given probability.
