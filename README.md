# TimeStruct.jl
[![Build Status](https://github.com/sintefore/TimeStruct.jl/workflows/CI/badge.svg?branch=main)](https://github.com/sintefore/TimeStruct.jl/actions?query=workflow%3ACI)
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

model = MOdel()
@varible(model, x[periods] >= 0)

@constraint(model, sum(x[t] for t in periods) <= 4)
@objective(model, sum(income[t] * x[t] for t in periods))
```

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


