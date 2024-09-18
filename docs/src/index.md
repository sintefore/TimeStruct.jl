# Introduction

Welcome to the documentation of the TimeStruct package!

## What is TimeStruct?

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

The package is registered in the general registry and can be installed in standard fashion

```julia
] add TimeStruct
```

This documentation consists of a manual explaining concepts and giving examples as well as a complete
API reference.

## Cite

If you find TimeStruct useful in your work, we kindly request that you cite the
following:
```

@misc{TimeStruct.jl,
  author       = {Flatberg, Truls and Hellemo, Lars},
  title        = {{TimeStruct.jl: Flexible time structures in optimization modelling}},
  month        = Jan,
  year         = 2024,
  doi          = {10.5281/zenodo.10511399},
  publisher    = {Zenodo},
  url          = {https://zenodo.org/records/10511399}
}
```

## Acknowledgements

This material is based upon work supported by the Research Council of Norway through the projects ZeroKyst (328721), MaritimeNH3 (328679) and CleanExport (308811).
