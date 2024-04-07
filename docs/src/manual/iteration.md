# Iteration utilities

## Basic iteration

All time structures are iterable over their operational time periods
```@repl ts
using TimeStruct

function iterate_ex(periods::TimeStructure)
    for t in periods
        writeln(t)
    end
end
```


## Iteration with previous

In many settings, e.g. tracking of storage, it is convenient to have
access to the previous time period. By using the custom iterator
[`withprev`](@ref) it is possible to return both the previous and 
current time period as a tuple when iterating:
```@repl ts
using TimeStruct
periods = SimpleTimes(5, 1);
collect(withprev(periods))
```



## Iteration with slices of time periods

Sometimes it is convenient to iterate through the time periods
as slices of fixed number of periods or minimum duration, e.g. in production planning
with minimum production runs. To simplify this process
there are several iterator wrappers that allows this kind of iteration pattern.


The [`slice`](@ref) function iterates through a time structure returning
subsequences of length at most `n` starting at each time period. 
```@repl ts
periods = SimpleTimes(5,1)
collect(collect(ts) for ts in slice(periods, 3))
```

This wrapper can be used for e.g. modelling of startup modelling with a minimum
uptime. The following example shows how this can be implemented as part of 
a JuMP model: 
```@ex
using JuMP, TimeStruct

periods = SimpleTimes(10,1)

m = Model()
@variable(m, startup[periods], Bin)

for ts in slice(periods, 3)
    @constraint(m, sum(startup[t] for t in ts) <= 1)
end
```
Similarly, if modelling shutdown decision with a minimum uptime,
it is possible to reverse the original time periods and then 
slice:
```@ex
m = Model()
@variable(m, shutdown[periods], Bin)

for ts in slice(Iterators.reverse(periods), 3)
    @constraint(m, sum(shutdown[t] for t in ts) <= 1)
end
```

!!! note
    Not all time structures can be reversed. Currently, it is only supported
    for operational time structures and operational scenarios.


## Slicing based on duration

If working with a time structure that has varying duration for its time periods,
it can be 

The [`slice_duration`](@ref) function iterates through a time structure returning
subsequences of duration at least `dur` starting at each time period.  
```@repl ts
periods = SimpleTimes(5,[1, 2, 1, 1.5, 0.5, 2])
collect(collect(ts) for ts in slice_duration(periods, 3))
```

## Indexing of operational time structures

It is possible to use indices for operational time structures, either directly
using [`SimpleTimes`](@ref) or [`CalendarTimes`](@ref) or by accessing an
operational scenario. 

```@repl ts
periods = TwoLevel(3, 100, SimpleTimes(10,1));

scenario = first(opscenarios(periods))
scenario[3]
```
