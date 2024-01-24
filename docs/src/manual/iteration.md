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



