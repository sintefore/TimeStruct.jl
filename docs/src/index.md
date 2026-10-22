# Introduction

Welcome to the documentation of the TimeStruct package!

## What is TimeStruct?

TimeStruct is a Julia package that supports the efficient development of optimization models with multi-horizon time modeling. The package is designed to be used in combination with [JuMP](https://jump.dev/) for optimization modeling in Julia.

The main concept is a [`TimeStructure`](@ref) which is an abstract type that enables iteration over a sequence of time periods. These time periods can serve as indices for optimization variables and can also facilitate the lookup of associated data values from time-varying profiles. By having a well-defined interface that is supported by all time structures, optimization models that are valid for arbitrary time structures can be written. The following example shows how a small optimization model can be set up in a function that accepts a general time structure and cost profile.

```@example
using JuMP, TimeStruct

function optimize_model(periods::TimeStructure, cost::TimeProfile)
    m = Model()
    @variable(m, x[periods] >= 0)
    @constraint(m, sum(x[t] for t in periods) >= 10)
    @objective(m, Min, sum(cost[t] * x[t] for t in periods))
    return m
end
```

## Why use TimeStruct?
In complex optimization models, tracking relationships between time periods often requires substantial coding, especially with stochastic versions. Time constraints can introduce subtle bugs, particularly with linking constraints between periods or scenarios, like managing storage inventory or dispatch constraints. Extra indices for time and scenarios complicate the code, making it harder to read, maintain, and adapt.

TimeStruct abstracts time structures, providing a common interface that simplifies the code and supports various time structures (operational, strategic/investment periods, and uncertainties). This abstraction allows modelers to focus on other model properties and facilitates running a single model for different time structures, and aids in the development of decomposition techniques.

## How to get started

The package is registered in the general registry and can be installed in the standard fashion:

```julia
] add TimeStruct
```

This documentation consists of a manual explaining concepts and giving examples, as well as a complete API reference.

## Citation

If you find TimeStruct useful in your work, we kindly request that you cite the following:

```bibtex
@article{Flatberg2025,
  doi = {10.21105/joss.07578},
  url = {https://doi.org/10.21105/joss.07578},
  year = {2025},
  publisher = {The Open Journal},
  volume = {10},
  number = {107},
  pages = {7578},
  author = {Truls Flatberg and Julian Straus and Lars Hellemo},
  title = {TimeStruct.jl -- flexible multi-horizon time modeling in optimization models},
  journal = {Journal of Open Source Software}
}
```

## Acknowledgements

This material is based upon work supported by the Research Council of Norway through the projects ZeroKyst (328721), MaritimeNH3 (328679) and CleanExport (308811).
