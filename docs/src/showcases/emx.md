# [EnergyModelsX](@id show-emx)

**[EnergyModelsX (EMX)](https://github.com/EnergyModelsX)** is a flexible multi-horizon energy system optimization framework using [`JuMP`](https://jump.dev/JuMP.jl/stable/).
It utilizes `TimeStruct` from the beginning and influenced some of the added features of `TimeStruct`.
Its implementation is outlined in the following sections.

## [Implementation of the core structures](@id show-emx-core)

The core package `EnergyModelsBase` differentiates between variables indexed over strategic periods and variables indexed over operational periods, similar to the battery sizing example.
As an example, consider the following two functions for variable declaration for a given `𝒯::TimeStructure`:

- [`variables_capacity(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)`](https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/10036d91949e69cae0fbdb8e1652b85d7f82742a/src/model.jl#L175) with, among others,

  ```julia
  @variable(m, cap_use[𝒩ᶜᵃᵖ, 𝒯] >= 0)
  @variable(m, cap_inst[𝒩ᶜᵃᵖ, 𝒯] >= 0)
  ```

- [`variables_opex(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)`](https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/10036d91949e69cae0fbdb8e1652b85d7f82742a/src/model.jl#L297C10-L297C82) with, among others,

  ```julia
  𝒯ᴵⁿᵛ = strategic_periods(𝒯)
  @variable(m, opex_var[𝒩ᵒᵖᵉˣ, 𝒯ᴵⁿᵛ])
  ```

These two functions highlight the simplicity of using `TimeStruct`, as the individual time structures allow for iterations within `JuMP` macros.
In addition, it simplifies the index sets, as changing the number of intermediate time structures through incorporating, *e.g.*, [`OperationalScenarios`](@ref man-oper-osc), does not require changes to the variable declarations.
The change in the structure through the incorporation of the operational scenarios is instead available within the individual `TimePeriod` type.

The same is also true for constraint functions, as shown in [`constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)`](https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/10036d91949e69cae0fbdb8e1652b85d7f82742a/src/constraint_functions.jl#L17):

```julia
@constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] <= m[:cap_inst][n, t])
```

Variables whose values are dependent on the previous operational period are only available for `Storage` nodes.
Its implementation is rather complex, but it is entirely relying on the [`withprev`](@ref man-iter-prev) functionality to decide whether it is the first operational period in a different `TimeStructure` as well as how it must behave in this situation.

The individual operational periods are linked in `EnergyModelsBase` through the internal function [`scale_op_sp`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/functions/#EnergyModelsBase.scale_op_sp) for the multiplication

```math
duration(t) * multiple\_strat(t_{inv}, t) * probability(t)
```

where ``t`` corresponds to an operational period and ``t_{inv}`` to a strategic period.

## [Advanced utilization](@id show-emx-adv)

### [`withprev` and its application](@id show-emx-adv-withprev)

As outlined, neither [`OperationalScenarios`](@ref man-oper-osc) nor [`RepresentativePeriods`](@ref man-oper-repr) were available in the initial development of **EMX**.
However, the adjustments toward including these were limited to constraints that require the previous periods, that is, constraints declared through the [`withprev`](@ref man-iter-prev) functionality.
All other constraints did not require any changes, as the respective `TimePeriod`s included the required information.

The implementation of the *[`Storage` level balance](https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/10036d91949e69cae0fbdb8e1652b85d7f82742a/src/constraint_functions.jl#L194C10-L195C1)* provides an example of how `TimeStruct` can be used.
It iterates through all potential subtypes of the given `TimeStructure`.
Multiple dispatch is included to identify whether the `TimeStructure` includes `OperationalScenarios` or `RepresentativePeriods`.
If this is the case, additional constraints can be incorporated.
Due to the iteration (and storing) of all previous periods, it is possible to identify exactly what constraint should be utilized for the first operational period in a given `TimeStructure`.

!!! tip "Proposed workflow"
    While it can be tempting to design models from the initial stage to include both operational scenarios and representative periods, it is beneficial to avoid including these.
    `TimeStruct` simplifies the introduction of either `TimeStructure` at a later stage.
    It is hence significantly easier to develop a model without considering complex time structures.

    If you do not have any constraints depending on the previous periods, you do not even have to make any changes to your model when including `OperationalScenarios` or `RepresentativePeriods`.

### [Chunks for unit commitment](@id show-emx-adv-chunk)

The functionality of `TimeStruct` for chunks based on the minimum required time is utilized in the *[unit commitment constraints of `Reformer` nodes](https://github.com/EnergyModelsX/EnergyModelsHydrogen.jl/blob/88a21ffae88b7ce199752aa5465313ad549718b6/src/constraints/reformer.jl#L259)* in [`EnergyModelsHydrogen`](https://energymodelsx.github.io/EnergyModelsHydrogen.jl/stable/).
In this context, we require a minimum time for starting the node, shutting the node down, and when the node is offline due to limitations in the dynamics of the chemical plant.
The used approach is similar to the `Storage` level balance, utilizing the [`withprev`](@ref man-iter-prev) functionality for the majority of the time structures.
However, once at the lowest level, [`chunk_duration`](@ref man-iter-chunk_dur) is used in addition to provide limits on changes between the different states.
The `eltype`s of the iterator allow for further iterations to have access to the number of operational periods.

### [Including strategic uncertainty](@id show-emx-adv-strat)

**EMX** was not tested to also include strategic uncertainty as described in *[TwoLevelTree structure](@ref man-multi-twoleveltree)*.
The basic functionalities of `EnergyModelsBase` and the majority of the developed packages do, however, not have any problems with incorporating strategic uncertainty, as the strategic periods are not linked.
In this case, the internal structure of `TimeStruct` allows the direct inclusion of strategic uncertainty without changes to the model.
The exception is when using the [`withprev`](@ref man-iter-prev) functionality on strategic periods, as is the case for the investments in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/).
However, it is expected that the inclusion does not require any changes directly to the code structure due to the function overload on the [`withprev`](@ref man-iter-prev) functionality.
