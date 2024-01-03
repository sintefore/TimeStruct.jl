# Introduction

Welcome to the documentation of the TimeStruct package!


## What is TimeStruct

TimeStruct is a Julia package that supports the efficient development of optimization models with multi-horizon time modelling. The package is designed to be used in combination with the JuMP package for optimization modeling in Julia.

The main concept is a [`TimeStructure`](@ref) which is an abstract type that enables iteration over a sequence of time periods. These time periods can serve as indices for optimization variables and can also facilitate the lookup of associated data values from time-varying profiles. By having a well-defined interface that is supported by all time structures, optimization models that are valid for arbitrary time structures can be written. The following example shows how a small optimization model can be set up in a function that accepts a general time structure and cost profile.


```@ex
    using JuMP, TimeStruct

    function(periods::TimeStructure, cost::TimeProfile)
        m = Model()
        @variable(m, x[periods] >= 0)
        @constraint(m, sum(x[t] for t in periods) >= 10)
        @objective(m, Min, sum(cost[t] * x[t] for t in periods))
    end
```

## How to get started