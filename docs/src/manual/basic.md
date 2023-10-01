```@meta
CurrentModule = TimeStruct
```

# Operational time structures

## SimpleTimes

The basic time structure is [`SimpleTimes`](@ref) which represents a continuous period of time divided into individual time periods of varying duration. 
The length of each time period is obtained by the [`duration(t)`](@ref) function.

```julia
julia> periods = SimpleTimes(5, [1, 1, 1, 5, 5]);

julia> durations = [duration(t) for t in periods]
```

## Calendar based 


## Representative periods

## Operational periods
