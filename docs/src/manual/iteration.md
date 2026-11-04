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

Both wrappers use [`isfirst`](@ref) to start anew in each operational scenario, representative period, and strategic period.
They hence work for time structures, strategic periods, representative periods, and the partitions of [`partition_duration`](@ref), but not for scenarios, which are not ordered.
When iterating the nodes of a [`TwoLevelTree`](@ref), `withprev` returns the parent node as previous node.
All wrappers of this page also accept iterators without known length, *e.g.*, `Iterators.filter`.

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

## [Indexing](@id man-iter-index)

It is in general not advised to use indexing directly for the introduced operational time structures and iterators.
Instead, it is beneficial to use the time structures directly as iterators.
However, `TimeStruct` supports indexing in the following cases.

### [Indexing of operational time structures](@id man-iter-index-ts)

It is possible to use indices for operational time structures, either directly using [`SimpleTimes`](@ref) or [`CalendarTimes`](@ref), or by accessing a strategic period, representative period, or operational scenario that directly contains one of them.
An index outside of the time structure results in a `BoundsError`.

```@repl ts
periods = TwoLevel(3, 100, SimpleTimes(10,1));

scenario = first(opscenarios(periods))
scenario[3]
```

Structures with several nested time structures, *e.g.*, a [`TwoLevel`](@ref), cannot be indexed.

### [Indexing of iterators](@id man-iter-index-iter)

The iterators returned by [`strat_periods`](@ref), [`repr_periods`](@ref), [`opscenarios`](@ref), and [`strategic_scenarios`](@ref) can be indexed with `itr[i]` and support `eachindex`, `keys`, and `itr[begin]`:

```@repl ts
sps = strat_periods(periods);
sps[2]
sps[end]
eachindex(sps)
```

`itr[end]` and `last(itr)` are only available for iterators of strategic and representative periods.
They are not available for iterators of scenarios, as scenarios are not ordered, nor for the nodes of a [`TwoLevelTree`](@ref), as a tree has several last nodes.
For the same reason, `last` is not defined for a [`TwoLevelTree`](@ref).

## [Ordering of periods](@id man-iter-order)

Strategic and representative periods can be compared with `<` and hence be sorted after `collect`.
Representative periods within strategic periods are compared first by their strategic period and then by their representative period, so that sorting follows the order of iteration:

```@repl ts
rps = RepresentativePeriods(2, 100, [0.5, 0.5], [SimpleTimes(5, 1), SimpleTimes(5, 1)]);
rp_pers = repr_periods(TwoLevel(2, 100, rps))
sort(rp_pers; rev = true)
```

The nodes of a [`TwoLevelTree`](@ref) form only a partial order: `n1 < n2` is `true` if `n1` is an ancestor of `n2`.
Nodes that are not on one path from the root are not ordered, as neither is smaller than the other.
`sort`, `max`, and `min` use instead `isless`, which compares only the strategic periods of the nodes, so that sorting puts ancestors before their descendants.

```@repl ts
tree = TwoLevelTree(3, [2, 2], SimpleTimes(5, 1));
sc_1, sc_2 = strategic_scenarios(tree);
root = first(strat_periods(sc_1));
leaf_1 = strat_periods(sc_1)[end];
leaf_2 = strat_periods(sc_2)[end];
root < leaf_1, leaf_1 < leaf_2, leaf_2 < leaf_1
```

Operational and strategic scenarios are not ordered and cannot be compared with `<`.
