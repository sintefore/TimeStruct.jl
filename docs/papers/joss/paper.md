---
title: 'TimeStruct.jl -- flexible multi-horizon time modelling in optimization models'
tags:
  - Julia
  - JuMP
  - optimization
  - modelling
authors:
  - name: Truls Flatberg
    orcid: 0000-0002-5914-6122
    equal-contrib: true
    corresponding: true # (This is how to denote the corresponding author)
    affiliation: 1
  - name: Julian Straus
    orcid: 0000-0001-8622-1936
    equal-contrib: true
    affiliation: 2
  - name: Lars Hellemo
    orcid: 0000-0001-5958-9794
    equal-contrib: true
    corresponding: false
    affiliation: 1
affiliations:
 - name: SINTEF Industry, Postboks 4760 Torgarden, 7465 Trondheim
   index: 1
 - name: SINTEF Energy Research, Postboks 4761 Torgarden, 7465 Trondheim
   index: 2

date: 11 October 2024
bibliography: paper.bib

---

# Summary

[TimeStruct](https://github.com/sintefore/TimeStruct.jl) is a Julia [@bezanson2017julia] package that provides an interface for abstracting time structures, primarily intended for use with the mathematical programming DSL JuMP [@Lubin2023].

TimeStruct simplifies the writing of key equations in optimization problems through separation of the indexing sets and the equation. Consequently, equations unaffected by the the chosen time structure, e.g., simple deterministic operational or stochastic programming models, must not be adjusted when changing the time structures. Hence, it simplifies both model development and subsequent switching between different time structures.

The package is already used in several optimization packages developed at [SINTEF](https://www.sintef.no/en/), e.g. [EnergyModelsX](https://github.com/EnergyModelsX/), [ZeroKyst](https://zerokyst.no/en/) and [MaritimeNH3](https://www.sintef.no/en/projects/2021/maritimenh3-enabling-implementation-of-ammonia-as-a-maritime-fuel/).

# Statement of need

For complex optimization models, a significant amount of code is typically used to track the relationships between time periods, further complicated if stochastic versions of the model are developed. Time constraints can be tricky to implement correctly. They can be a source of subtle bugs, in particular when more complicated structures are involved in models with linking constraints between time periods or scenarios. One example for this type of constraints is keeping track of a storage inventory over time or incorporate dispatch constraints.

Modellers typically use extra indices to keep track of time and scenarios, making the code harder to read, maintain and change to support other or multiple time structures. This complexity can be an obstacle during development, testing and debugging, as it is easier to work with simpler time structures.

By abstracting out the time structures and providing a common interface, TimeStruct allows the modeller to concentrate on other properties of the model, keeping the code simple while supporting a large variety of time structures (pure operational, strategic/investment periods and operational periods, including operational uncertainty and/or strategic uncertainty).

Through providing a common interface with time structure semantics, TimeStruct simplifies running a single model for different time structures. It may be hence used to develop decomposition techniques to exploit specific structures.

# Example of use

For a full overview of the functionality of TimeStruct, please see the online [documentation](https://sintefore.github.io/TimeStruct.jl/stable/).

During development and for operational analyses, simple time structures where, *e.g.*, time is divided into discrete time periods with (operational) decision variables in time period, can be useful. With TimeStruct, such structures can be easily used in any optimization model. The example in \autoref{fig:simple} shows the basic time structure `SimpleTimes` which represents a continuous period of time divided into individual time periods of varying duration. The length of each time period is obtained by the `duration(t)` function.

![Simple time structure with only operational periods.\label{fig:simple}](simple.pdf)

One of the main motivations for the development of TimeStruct is to support multi-horizon time structures [@kaut2014multi]. As a simple example of a multi-horizon time structure, the time structure `TwoLevel` allows for a two level approach, combining an ordered sequence of strategic periods (typically used for binary capacity expansion) with given duration and an associated operational time structure (for operational decisions using the available capacity in the associated strategic period) as illustrated in \autoref{fig:twolevel}.

![A typical two-level time structure.\label{fig:twolevel}](twolevel.pdf)

Using the interfaces defined in `TimeStruct`, it is easy to write models that are valid across different time structures.
The following example shows a simple model with a production variable, $x$, defined for all operational time periods and a constraint on the maximum total production cost for each strategic period:
```julia
using JuMP, TimeStruct
function create_model(periods::TimeStructure, cost::TimeProfile, max_cost)
    model = Model()
    @variable(model, x[periods])
    for sp in strat_periods(periods)
      @constraint(model, sum(cost[t] * x[t] for t in sp) <= max_cost)
    end
    return model
end
```
This model will be valid for both examples above, producing one constraint for the `SimpleTimes` and three constraints for
the strategic periods of the `TwoLevel` example.
```julia
latex_formulation(create_model(SimpleTimes([1, 1, 1, 5, 5]), FixedProfile(3), 10))
```
$$
3 x_{t1} + 3 x_{t2} + 3 x_{t3} + 3 x_{t4} + 3 x_{t5} \leq 10
$$
```julia
latex_formulation(create_model(TwoLevel(3, SimpleTimes(5,1)), FixedProfile(3), 10))
```
$$
\begin{aligned}
& 3 x_{sp1-t1} + 3 x_{sp1-t2} + 3 x_{sp1-t3} + 3 x_{sp1-t4} + 3 x_{sp1-t5} \leq 10\\
 & 3 x_{sp2-t1} + 3 x_{sp2-t2} + 3 x_{sp2-t3} + 3 x_{sp2-t4} + 3 x_{sp2-t5} \leq 10\\
 & 3 x_{sp3-t1} + 3 x_{sp3-t2} + 3 x_{sp3-t3} + 3 x_{sp3-t4} + 3 x_{sp3-t5} \leq 10\\
\end{aligned}
$$

Different time structures may be combined to construct more complex structures. One example is the combination of a `TwoLevel` time structure with more complex operational structures like `RepresentativePeriods` and `OperationalScenarios`. These may be used alone or in combination, as shown in \autoref{fig:two_complex}.

![A more complex two-level time structure.\label{fig:two_complex}](two_complex.pdf)

`TimeStruct.jl` also provides data structures for representing parameter data, providing efficient representation and indexing by time period for data with varying level of redundancy. Functionality for computation of discount factors for each time period to facilitate calculation of present values is also included.

# Example applications

TimeStruct is used in multiple optimization models developed at SINTEF. One early application is in [EnergyModelsX](https://github.com/EnergyModelsX/) [@hellemo2024energymodelsx], simplifying the code in `EnergyModelsBase.jl` considerably, and allowing to add capabilities for stochastic programming versions of the model with little extra effort, see, *e.g.*, [@bodal2024hydrogen;@svendsmark2024developing] for example applications of EnergyModelsX.

It has also been used in the logistics models developed in the project 'Sirkulær masseforvaltning' for planning in the rock and gravel industry, as well as for hydrogen facility location optimization in the 'ZeroKyst' project. Ongoing activities in the EU funded projects 'H2GLASS' and 'FLEX4FACT' involve the use of TimeStruct [@kitch2024optimal].

# Acknowledgements

The development of `TimeStruct` was funded by the Research Council of Norway through the projects [ZeroKyst](https://zerokyst.no/en/) ([328721](https://prosjektbanken.forskningsradet.no/project/FORISS/328721)), [MaritimeNH3](https://www.sintef.no/en/projects/2021/maritimenh3-enabling-implementation-of-ammonia-as-a-maritime-fuel/) ([328679](https://prosjektbanken.forskningsradet.no/project/FORISS/328679)) and [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/) ([308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811))

# References
