# Iteration utilities

## Basic iteration

All time structures are iterable over all operational time periods


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

```@repl ts
using JuMP


```


