"""
    ScenarioPairing(scenarios::Matrix{<:Integer}, probability::Vector{<:Real}; check_marginals::Symbol = :warn)
    ScenarioPairing(scenarios::Vector{<:AbstractVector{<:Integer}}, probability::Vector{<:Real}; check_marginals::Symbol = :warn)

A set of joint scenario paths through the representative periods of a time structure. Each
row of `scenarios` (or each element when providing a vector of vectors) defines a path
through specifying the index of the operational scenario used in each representative
period. `probability` provides the probability of each path.

The path probabilities are *consistent* with the operational scenarios if, for each
representative period, the probabilities of the paths using a scenario sum to the
probability of that scenario. The consistency is checked when the paths are created. The
keyword `check_marginals` specifies whether an inconsistency results in a warning
(`:warn`), an error (`:error`), or is ignored (`:none`). Alternatively, the scenario
probabilities can be derived from the path probabilities through the keyword
`scenario_probability = :from_pairing` of [`RepresentativePeriods`](@ref).

A `ScenarioPairing` is either given directly or generated from the scenario probabilities by
a [`PairingMethod`](@ref) through [`generate_pairing`](@ref). It can be provided to
[`scenario_paths`](@ref) or stored in a [`RepresentativePeriods`](@ref) time structure
through the keyword argument `pairing`.

## Example

```julia
# Three paths through two representative periods
ScenarioPairing([1 1; 2 3; 3 2], [0.5, 0.3, 0.2])
ScenarioPairing([[1, 1], [2, 3], [3, 2]], [0.5, 0.3, 0.2])
```
"""
struct ScenarioPairing
    scenarios::Matrix{Int}
    probability::Vector{Float64}
    check_marginals::Symbol
    function ScenarioPairing(
        scenarios::Matrix{<:Integer},
        probability::Vector{<:Real};
        check_marginals::Symbol = :warn,
    )
        if check_marginals ∉ (:warn, :error, :none)
            throw(ArgumentError("`check_marginals` must be `:warn`, `:error`, or `:none`."))
        elseif size(scenarios, 1) != length(probability)
            throw(
                ArgumentError(
                    "The number of paths ($(size(scenarios, 1))) must be equal to the " *
                    "length of `probability` ($(length(probability))).",
                ),
            )
        elseif any(<(0), probability)
            throw(ArgumentError("The path probabilities must be non-negative."))
        elseif !isapprox(sum(probability), 1; atol = 1e-6)
            @warn(
                "The sum of the path probabilities is given by $(sum(probability)). " *
                "This can lead to unexpected behavior."
            )
        end
        return new(
            convert(Matrix{Int}, scenarios),
            convert(Vector{Float64}, probability),
            check_marginals,
        )
    end
end
function ScenarioPairing(
    scenarios::Vector{<:AbstractVector{<:Integer}},
    probability::Vector{<:Real};
    kwargs...,
)
    n_rp = isempty(scenarios) ? 0 : length(first(scenarios))
    if any(length(path) != n_rp for path in scenarios)
        throw(ArgumentError("All paths must have the same length."))
    end
    mat = [scenarios[k][r] for k in eachindex(scenarios), r in 1:n_rp]
    return ScenarioPairing(mat, probability; kwargs...)
end

function Base.show(io::IO, pairing::ScenarioPairing)
    return print(io, "ScenarioPairing with $(size(pairing.scenarios, 1)) paths")
end

"""
    abstract type PairingMethod

Supertype of the methods that generate a [`ScenarioPairing`](@ref) from the probabilities of
the operational scenarios of the representative periods. The only method included in
`TimeStruct` is [`DiagonalPairing`](@ref). Other methods, *e.g.*, all combinations of
scenarios or sampled paths, are scenario generation methods that can be implemented in
other packages.

A subtype `M` implements

- `_paths(method::M, probs)`, returning the paths as a vector of scenario index vectors and
  the path probabilities, given the scenario probabilities `probs[r][s]`, and optionally
- `_default_check_marginals(method::M)`, returning the default value of the keyword
  `check_marginals` of [`generate_pairing`](@ref) (`:warn` if not implemented).

A `PairingMethod` can be used wherever a `ScenarioPairing` is expected, that is, as the
keyword argument `pairing` of [`RepresentativePeriods`](@ref) or as argument to
[`scenario_paths`](@ref). The method is then resolved with the scenario probabilities of
the time structure. In a `RepresentativePeriods`, the resulting `ScenarioPairing` is stored,
so that the method is only applied once.
"""
abstract type PairingMethod end

const PairingOrMethod = Union{ScenarioPairing,PairingMethod}

_default_check_marginals(::PairingMethod) = :warn

"""
    generate_pairing(method::PairingMethod, ts; check_marginals = :warn)
    generate_pairing(method::PairingMethod, probs; check_marginals = :warn)

Returns a [`ScenarioPairing`](@ref) that combines the operational scenarios of the
representative periods into paths with `method`. The scenario probabilities are obtained
through [`scenario_probabilities`](@ref) of the time structure `ts`, which must not have
probabilities per strategic period, or given directly as `probs[r][s]`.

The keyword `check_marginals` is passed to `ScenarioPairing`. Its default depends on the
method.
"""
function generate_pairing(
    method::PairingMethod,
    ts_or_probs;
    check_marginals = _default_check_marginals(method),
)
    scens, path_probs = _paths(method, _probs(ts_or_probs))
    return ScenarioPairing(scens, path_probs; check_marginals)
end

const Probabilities = Vector{<:AbstractVector{<:Real}}

# Scenario probabilities `probs[r][s]` from a time structure or given directly
function _probs(ts::TimeStructure)
    probs = scenario_probabilities(ts)
    if !(probs isa Vector{Vector{Float64}})
        throw(
            ArgumentError(
                "The scenario probabilities of $(typeof(ts)) are given per strategic " *
                "period. Generate the pairing for each strategic period instead.",
            ),
        )
    end
    return probs
end
_probs(probs::Probabilities) = [convert(Vector{Float64}, p) for p in probs]

"""
    DiagonalPairing()

Pairing method that pairs the operational scenarios with the same index across all
representative periods, that is, path `k` consists of scenario `k` in every representative
period. Representative periods with a single scenario are part of all paths.

This corresponds to *coherent annual paths* where scenario `k` describes the same weather
year (or similar) in all representative periods. It requires that all representative
periods with more than one scenario have the same number of scenarios with the same
probabilities. The path probabilities are then the scenario probabilities, and hence
consistent.
"""
struct DiagonalPairing <: PairingMethod end

function _paths(::DiagonalPairing, probs)
    multi = [r for r in eachindex(probs) if length(probs[r]) > 1]
    isempty(multi) && return [ones(Int, length(probs))], [prod(only, probs)]

    ref = probs[first(multi)]
    for r in multi
        if length(probs[r]) != length(ref)
            throw(
                ArgumentError(
                    "`DiagonalPairing` requires that all representative periods have the " *
                    "same number of operational scenarios. Representative period " *
                    "$(first(multi)) has $(length(ref)) while representative period $r " *
                    "has $(length(probs[r])).",
                ),
            )
        elseif !isapprox(probs[r], ref; atol = 1e-6)
            throw(
                ArgumentError(
                    "`DiagonalPairing` requires that the scenario probabilities are " *
                    "identical in all representative periods. This is not the case for " *
                    "representative periods $(first(multi)) and $r.",
                ),
            )
        end
    end
    scens = [[length(p) == 1 ? 1 : k for p in probs] for k in eachindex(ref)]
    return scens, copy(ref)
end
