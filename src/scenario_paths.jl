# Validated paths and probabilities of a `ScenarioPairing` for the scenario probabilities
# `probs[r][s]`
function _pair_scenarios(pairing::ScenarioPairing, probs::Vector{Vector{Float64}})
    _validate_paths(pairing, probs)
    scens = _path_rows(pairing)
    _check_marginals(scens, pairing.probability, probs, pairing.check_marginals)
    return scens, copy(pairing.probability)
end

function _path_rows(pairing::ScenarioPairing)
    return [pairing.scenarios[k, :] for k in axes(pairing.scenarios, 1)]
end

# Throws an error if the paths do not match the number of scenarios in `probs`
function _validate_paths(pairing::ScenarioPairing, probs::Vector{Vector{Float64}})
    if size(pairing.scenarios, 2) != length(probs)
        throw(
            ArgumentError(
                "The paths of `ScenarioPairing` specify $(size(pairing.scenarios, 2)) " *
                "representative periods while the time structure has $(length(probs)).",
            ),
        )
    end
    for r in eachindex(probs), k in axes(pairing.scenarios, 1)
        if pairing.scenarios[k, r] ∉ eachindex(probs[r])
            throw(
                ArgumentError(
                    "Path $k uses scenario $(pairing.scenarios[k, r]) in representative " *
                    "period $r which only has $(length(probs[r])) operational scenarios.",
                ),
            )
        end
    end
end

# The first `len` representative periods of `rep_periods` with the probabilities of the
# operational scenarios given by the sum of the probabilities of the paths using them
function _probabilities_from_pairing(rep_periods::Vector, len::Integer, pairing)
    if isnothing(pairing)
        throw(
            ArgumentError(
                "`scenario_probability = :from_pairing` requires the keyword `pairing`.",
            ),
        )
    end
    probs = _scenario_probs(rep_periods[1:len])
    _validate_paths(pairing, probs)
    marg = _marginals(_path_rows(pairing), pairing.probability, probs)
    unused =
        [(r, s) for r in eachindex(marg) for s in eachindex(marg[r]) if marg[r][s] == 0]
    if !isempty(unused)
        @warn(
            "The following operational scenarios are not part of any path and get zero " *
            "probability: " *
            join(("scenario $s of representative period $r" for (r, s) in unused), ", ") *
            "."
        )
    end
    new_rps = copy(rep_periods)
    for r in 1:len
        rp = rep_periods[r]
        if rp isa OperationalScenarios
            new_rps[r] = OperationalScenarios(rp.len, rp.scenarios, marg[r])
        elseif length(probs[r]) > 1
            throw(
                ArgumentError(
                    "`scenario_probability = :from_pairing` requires that each " *
                    "representative period is an `OperationalScenarios` or has a single " *
                    "scenario. Representative period $r is a $(typeof(rp)).",
                ),
            )
        end
    end
    return new_rps
end

# The sum of the path probabilities `path_probs` for each scenario `s` of each
# representative period `r`, indexed as `[r][s]`
function _marginals(scens, path_probs, probs)
    marg = [zeros(length(p)) for p in probs]
    for (k, s) in enumerate(scens), r in eachindex(s)
        marg[r][s[r]] += path_probs[k]
    end
    return marg
end

function _check_marginals(scens, path_probs, probs, mode::Symbol)
    mode == :none && return
    marg = _marginals(scens, path_probs, probs)
    dev = maximum(maximum(abs.(marg[r] .- probs[r])) for r in eachindex(probs))
    dev <= 1e-6 && return
    msg =
        "The path probabilities are not consistent with the scenario probabilities. " *
        "The maximum deviation between the summed path probabilities of a scenario and " *
        "the scenario probability is $dev."
    mode == :error && throw(ArgumentError(msg))
    @warn msg
end

# Probabilities of the operational scenarios of each of the given representative periods
function _scenario_probs(rps)
    return [Float64[probability_scen(osc) for osc in opscenarios(rp)] for rp in rps]
end

"""
    struct ScenarioPath{OSC<:AbstractOperationalScenario}

A joint scenario path through all representative periods of a time structure. It consists of
one operational scenario per representative period and has an associated probability. It is
created through the function [`scenario_paths`](@ref).

Iterating through a `ScenarioPath` provides the time periods of the selected operational
scenarios, ordered by representative period. These time periods are the same as obtained
when iterating through the time structure itself, so they can be used directly to index
variables and time profiles. The function [`opscenarios`](@ref) returns the selected
operational scenario of each representative period.

!!! note
    The function [`probability`](@ref) of a time period within a path returns the
    probability of the operational scenario, not of the path. Use `probability(path)` to
    obtain the probability of the path.
"""
struct ScenarioPath{OSC<:AbstractOperationalScenario}
    id::Int
    scens::Vector{Int}
    probability::Float64
    opscens::Vector{OSC}
end

_path(path::ScenarioPath) = path.id

probability(path::ScenarioPath) = path.probability
opscenarios(path::ScenarioPath) = path.opscens

"""
    path_scenarios(path::ScenarioPath)

Returns the index of the operational scenario used in each representative period of `path`.
"""
path_scenarios(path::ScenarioPath) = path.scens

function Base.show(io::IO, path::ScenarioPath)
    return print(io, "path$(_path(path))(sc", join(path.scens, ","), ")")
end

# Add basic functions of iterators
Base.length(path::ScenarioPath) = sum(length, path.opscens)
Base.IteratorEltype(::Type{<:ScenarioPath}) = Base.EltypeUnknown()
function Base.iterate(path::ScenarioPath, state = (1, nothing))
    rp, inner = state
    rp > length(path.opscens) && return nothing
    osc = path.opscens[rp]
    next = isnothing(inner) ? iterate(osc) : iterate(osc, inner)
    isnothing(next) && return iterate(path, (rp + 1, nothing))
    return next[1], (rp, next[2])
end

"""
    scenario_paths(ts)
    scenario_paths(ts, pairing::ScenarioPairing)
    scenario_paths(ts, method::PairingMethod)

Returns a vector of [`ScenarioPath`](@ref)s, that is, joint operational scenarios across the
representative periods of `ts`. The [`ScenarioPairing`](@ref) `pairing` specifies how the
scenarios of the individual representative periods are combined. A [`PairingMethod`](@ref)
is resolved with the scenario probabilities of `ts` (for each strategic period in the case
of [`TwoLevel`](@ref) and [`TwoLevelTree`](@ref) time structures).

If `pairing` is not provided, the pairing stored in the [`RepresentativePeriods`](@ref) of
`ts` is used. An error is thrown if no pairing is stored and `ts` has more than one
representative period. A provided `pairing` overrides the stored pairing, *e.g.*, for
analysing the sensitivity of the results to the assumed coupling.

Scenario paths make the coupling between operational scenarios of different representative
periods explicit instead of relying on the positional enumeration of the scenarios. They
can be used, *e.g.*, for constraints that should hold for each coherent annual path, such as
annual budgets or storage levels linked across representative periods.

`ts` can be a time structure with [`RepresentativePeriods`](@ref) or a strategic period of a
[`TwoLevel`](@ref) or [`TwoLevelTree`](@ref). For `TwoLevel` and `TwoLevelTree` time
structures, the paths of all strategic periods are returned, with path ids restarting in
each strategic period. The path probabilities are conditional on the strategic period,
*i.e.*, they do not include the branch probabilities of a `TwoLevelTree`. Time structures
without `RepresentativePeriods` result in one path per operational scenario.

## Example

```julia
day = SimpleTimes(24, 1)
oscs = OperationalScenarios(3, day)
ts = RepresentativePeriods(2, 8760, oscs)

# Scenario k in both representative periods, 3 paths with probability 1/3
scenario_paths(ts, DiagonalPairing())
# Given paths and probabilities
scenario_paths(ts, ScenarioPairing([1 1; 2 2; 3 3; 2 3; 3 2], [0.2, 0.2, 0.2, 0.2, 0.2]))

# Pairing stored in the time structure
ts = RepresentativePeriods(2, 8760, oscs; pairing = DiagonalPairing())
scenario_paths(ts)

for path in scenario_paths(ts, DiagonalPairing())
    probability(path)
    for t in path
        # Time periods of the path in all representative periods
    end
end
```
"""
function scenario_paths(ts, pairing::ScenarioPairing)
    oscs_rp = [collect(opscenarios(rp)) for rp in repr_periods(ts)]
    probs = _scenario_probs(repr_periods(ts))
    scens, path_probs = _pair_scenarios(pairing, probs)
    return [
        ScenarioPath(k, s, path_probs[k], [oscs_rp[r][s[r]] for r in eachindex(s)]) for
        (k, s) in enumerate(scens)
    ]
end
function scenario_paths(ts, method::PairingMethod)
    return scenario_paths(ts, generate_pairing(method, ts))
end
scenario_paths(ts) = scenario_paths(ts, _stored_pairing(ts))

# `TwoLevel` and `TwoLevelTree`: concatenate the paths of the strategic periods. The
# methods are defined for each argument type to avoid ambiguities with the generic methods.
function scenario_paths(ts::Union{TwoLevel,TwoLevelTree}, pairing::ScenarioPairing)
    return _strat_paths(ts, pairing)
end
function scenario_paths(ts::Union{TwoLevel,TwoLevelTree}, method::PairingMethod)
    return _strat_paths(ts, method)
end
scenario_paths(ts::Union{TwoLevel,TwoLevelTree}) = _strat_paths(ts)
function _strat_paths(ts, args...)
    return collect(
        Iterators.flatten(scenario_paths(sp, args...) for sp in strategic_periods(ts)),
    )
end

"""
    path_marginals(ts)
    path_marginals(ts, pairing::Union{ScenarioPairing, PairingMethod})

Returns the sum of the probabilities of the [`scenario_paths`](@ref) that use each
operational scenario, as a vector indexed by representative period and scenario,
`marg[r][s]`. The path probabilities are consistent with the operational scenarios if this
equals the scenario probabilities.

For [`TwoLevel`](@ref) and [`TwoLevelTree`](@ref) time structures, a vector with the result
for each strategic period is returned.
"""
function path_marginals(ts, pairing::ScenarioPairing)
    probs = _scenario_probs(repr_periods(ts))
    scens, path_probs = _pair_scenarios(pairing, probs)
    return _marginals(scens, path_probs, probs)
end
function path_marginals(ts, method::PairingMethod)
    return path_marginals(ts, generate_pairing(method, ts))
end
path_marginals(ts) = path_marginals(ts, _stored_pairing(ts))

function path_marginals(ts::Union{TwoLevel,TwoLevelTree}, pairing::ScenarioPairing)
    return _strat_marginals(ts, pairing)
end
function path_marginals(ts::Union{TwoLevel,TwoLevelTree}, method::PairingMethod)
    return _strat_marginals(ts, method)
end
path_marginals(ts::Union{TwoLevel,TwoLevelTree}) = _strat_marginals(ts)
function _strat_marginals(ts, args...)
    return [path_marginals(sp, args...) for sp in strategic_periods(ts)]
end

"""
    scenario_probabilities(ts)

Returns the probabilities of the operational scenarios of each representative period of
`ts`, as a vector indexed by representative period and scenario, `probs[r][s]`.
Time structures without `RepresentativePeriods` are treated as a single representative
period.

The function provides the input for a [`PairingMethod`](@ref) generating a
[`ScenarioPairing`](@ref), *e.g.*, through sampling or enumerating combinations of
scenarios.

For [`TwoLevel`](@ref) and [`TwoLevelTree`](@ref) time structures, a vector with the result
for each strategic period is returned.
"""
scenario_probabilities(ts) = _scenario_probs(repr_periods(ts))
function scenario_probabilities(ts::Union{TwoLevel,TwoLevelTree})
    return [scenario_probabilities(sp) for sp in strategic_periods(ts)]
end

# The pairing stored in the time structure, or a default if none is needed
function _stored_pairing(ts)
    pairing = _pairing(ts)
    if isnothing(pairing)
        if length(repr_periods(ts)) > 1
            throw(
                ArgumentError(
                    "No scenario pairing is specified for the representative periods. " *
                    "Provide a `ScenarioPairing` or a `PairingMethod` either as argument " *
                    "to `scenario_paths` " *
                    "or through the keyword `pairing` of `RepresentativePeriods`.",
                ),
            )
        end
        # With a single representative period, each scenario forms its own path
        pairing = DiagonalPairing()
    end
    return pairing
end

# The pairing stored in the time structure, or `nothing` if none is stored
_pairing(ts) = nothing
_pairing(ts::RepresentativePeriods) = ts.pairing
_pairing(sp::Union{StrategicPeriod,StratNode}) = _pairing(sp.operational)
_pairing(ts::SingleStrategicPeriod) = _pairing(ts.ts)
