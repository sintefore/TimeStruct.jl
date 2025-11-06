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
