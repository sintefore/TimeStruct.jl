# TimeStruct.jl
[![DOI](https://joss.theoj.org/papers/10.21105/joss.07578/status.svg)](https://doi.org/10.21105/joss.07578)
[![Build Status](https://github.com/sintefore/TimeStruct.jl/workflows/CI/badge.svg)](https://github.com/sintefore/TimeStruct.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/sintefore/TimeStruct.jl/graph/badge.svg?token=W4UGEJD8TZ)](https://codecov.io/gh/sintefore/TimeStruct.jl)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sintefore.github.io/TimeStruct.jl/stable/)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://sintefore.github.io/TimeStruct.jl/dev/)

TimeStruct is a Julia package that supports the efficient development of optimization models with multi-horizon time modelling and possible uncertainty. 
The package is designed to be used in combination with the JuMP package for optimization modeling in Julia.

## Installation

```
] add TimeStruct
```

## Example

The following shows a simple example of usage. For further details we refer to the documentation. 

```julia 
using JuMP
using TimeStruct

periods = SimpleTimes(10, 1)    # 10 periods of length 1
income = FixedProfile(5.0)      # Fixed income profile 

model = Model()
@variable(model, x[periods] >= 0)

@constraint(model, sum(x[t] for t in periods) <= 4)
@objective(model, Min, sum(income[t] * x[t] for t in periods))
```

## Cite
If you find TimeStruct useful in your work, we kindly request that you cite the
following [paper](https://doi.org/10.21105/joss.07578):
```
@article{Flatberg2025,
  doi = {10.21105/joss.07578},
  url = {https://doi.org/10.21105/joss.07578},
  year = {2025},
  publisher = {The Open Journal},
  volume = {10},
  number = {107},
  pages = {7578},
  author = {Truls Flatberg and Julian Straus and Lars Hellemo},
  title = {TimeStruct.jl -- flexible multi-horizon time modelling in optimization models},
  journal = {Journal of Open Source Software}
} 
```


## Acknowledgements

This material is based upon work supported by the Research Council of Norway through the projects ZeroKyst (328721), MaritimeNH3 (328679) and CleanExport (308811).


