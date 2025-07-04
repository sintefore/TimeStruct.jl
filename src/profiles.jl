abstract type TimeProfile{T} end

profilevaluetype(_::TimeProfile{T}) where {T} = T

"""
    FixedProfile(val)

Time profile with a constant value for all time periods.

## Example
```julia
profile = FixedProfile(5)
```
"""
struct FixedProfile{T} <: TimeProfile{T}
    val::T
    function FixedProfile(val::T) where {T}
        if T <: Array
            throw(
                ArgumentError(
                    "It is not possible to use an `Array` as input to `FixedProfile`.",
                ),
            )
        else
            new{T}(val)
        end
    end
end

function Base.getindex(
    fp::FixedProfile,
    _::T,
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return fp.val
end

function Base.convert(::Type{FixedProfile{T}}, fp::FixedProfile{S}) where {T,S}
    return FixedProfile(convert(T, fp.val))
end
function _internal_convert(::Type{T}, fp::FixedProfile{S}) where {T,S}
    return FixedProfile(convert(T, fp.val))
end

"""
    OperationalProfile(vals::Vector{T}) where {T}

Time profile with a value that varies with the operational time period. This profile cannot
be accessed using [`AbstractOperationalScenario`](@ref), [`AbstractRepresentativePeriod`](@ref),
or [`AbstractStrategicPeriod`](@ref).

If too few values are provided, the last provided value will be repeated.

## Example
```julia
profile = OperationalProfile([1, 2, 3, 4, 5])
```
"""
struct OperationalProfile{T} <: TimeProfile{T}
    vals::Vector{T}
    function OperationalProfile(vals::Vector{T}) where {T}
        if T <: Array
            throw(
                ArgumentError(
                    "It is not possible to use a `Vector{<:Array}` as input " *
                    "to an `OperationalProfile`.",
                ),
            )
        else
            new{T}(vals)
        end
    end
end

function Base.getindex(op::OperationalProfile, i::TimePeriod)
    return op.vals[_oper(i) > length(op.vals) ? end : _oper(i)]
end
function Base.getindex(op::OperationalProfile, i::TimeStructurePeriod)
    return error("Type $(typeof(i)) can not be used as index for an operational profile")
end

function Base.convert(::Type{OperationalProfile{T}}, op::OperationalProfile{S}) where {T,S}
    return OperationalProfile(convert.(T, op.vals))
end
function _internal_convert(::Type{T}, op::OperationalProfile{S}) where {T,S}
    return OperationalProfile(convert.(T, op.vals))
end

"""
    StrategicProfile(vals::Vector{P}) where {T, P<:TimeProfile{T}}
    StrategicProfile(vals::Vector)

Time profile with a separate time profile for each strategic period.

If too few profiles are provided, the last given profile will be repeated.

## Example
```julia
# Varying values in each strategic period
profile = StrategicProfile([OperationalProfile([1, 2]), OperationalProfile([3, 4, 5])])
 # The same value in each strategic period
profile = StrategicProfile([1, 2, 3, 4, 5])
```
"""
struct StrategicProfile{T,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end
function StrategicProfile(vals::Vector{T}) where {T}
    if T <: Array
        throw(
            ArgumentError(
                "It is not possible to use a `Vector{<:Array}` as input " *
                "to a `StrategicProfile`.",
            ),
        )
    else
        return StrategicProfile([FixedProfile(v) for v in vals])
    end
end
function StrategicProfile(vals::Vector{T}) where {T<:TimeProfile}
    ET = promote_type((profilevaluetype(v) for v in vals)...)
    return StrategicProfile(_internal_convert.(ET, vals))
end

function _internal_convert(::Type{T}, sp::StrategicProfile{S}) where {T,S}
    return StrategicProfile(_internal_convert.(T, sp.vals))
end

function _value_lookup(::HasStratIndex, sp::StrategicProfile, period)
    return sp.vals[_strat_per(period) > length(sp.vals) ? end : _strat_per(period)][_period(
        period,
    )]
end

function _value_lookup(::NoStratIndex, sp::StrategicProfile, period)
    return error("Type $(typeof(period)) can not be used as index for a strategic profile")
end

function Base.getindex(
    sp::StrategicProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return _value_lookup(StrategicIndexable(T), sp, period)
end

"""
    ScenarioProfile(vals::Vector{P}) where {T, P<:TimeProfile{T}}
    ScenarioProfile(vals::Vector)

Time profile with a separate time profile for each scenario. This profile cannot
be accessed using [`AbstractRepresentativePeriod`](@ref) or [`AbstractStrategicPeriod`](@ref).

If too few profiles are provided, the last given profile will be repeated.

## Example
```julia
# Varying values in each operational scenario
profile = ScenarioProfile([OperationalProfile([1, 2]), OperationalProfile([3, 4, 5])])
 # The same value in each operational scenario
profile = ScenarioProfile([1, 2, 3, 4, 5])
```
"""
struct ScenarioProfile{T,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end

function ScenarioProfile(vals::Vector{T}) where {T<:TimeProfile}
    ET = promote_type((profilevaluetype(v) for v in vals)...)
    return ScenarioProfile(_internal_convert.(ET, vals))
end

function _internal_convert(::Type{T}, sp::ScenarioProfile{S}) where {T,S}
    return ScenarioProfile(_internal_convert.(T, sp.vals))
end

function ScenarioProfile(vals::Vector{T}) where {T}
    if T <: Array
        throw(
            ArgumentError(
                "It is not possible to use a `Vector{<:Array}` as input " *
                "to a `ScenarioProfile`.",
            ),
        )
    else
        return ScenarioProfile([FixedProfile(v) for v in vals])
    end
end

function _value_lookup(::HasScenarioIndex, sp::ScenarioProfile, period)
    return sp.vals[_opscen(period) > length(sp.vals) ? end : _opscen(period)][_period(
        period,
    )]
end

function _value_lookup(::NoScenarioIndex, sp::ScenarioProfile, period)
    return error("Type $(typeof(period)) can not be used as index for a scenario profile")
end

function Base.getindex(
    sp::ScenarioProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return _value_lookup(ScenarioIndexable(T), sp, period)
end

"""
    RepresentativeProfile(vals::Vector{P}) where {T, P<:TimeProfile{T}}
    RepresentativeProfile(vals::Vector)

Time profile with a separate time profile for each representative period. This profile cannot
be accessed using [`AbstractStrategicPeriod`](@ref).

If too few profiles are provided, the last given profile will be repeated.

## Example
```julia
# Varying values in each representative period
profile = RepresentativeProfile([OperationalProfile([1, 2]), OperationalProfile([3, 4, 5])])
 # The same value in each representative period
profile = RepresentativeProfile([1, 2, 3, 4, 5])
```
"""
struct RepresentativeProfile{T,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end
function RepresentativeProfile(vals::Vector{T}) where {T}
    if T <: Array
        throw(
            ArgumentError(
                "It is not possible to use a `Vector{<:Array}` as input " *
                "to a `RepresentativeProfile`.",
            ),
        )
    else
        return RepresentativeProfile([FixedProfile(v) for v in vals])
    end
end
function RepresentativeProfile(vals::Vector{T}) where {T<:TimeProfile}
    ET = promote_type((profilevaluetype(v) for v in vals)...)
    return RepresentativeProfile(_internal_convert.(ET, vals))
end

function _internal_convert(::Type{T}, rp::RepresentativeProfile{S}) where {T,S}
    return RepresentativeProfile(_internal_convert.(T, rp.vals))
end

function _value_lookup(::HasReprIndex, rp::RepresentativeProfile, period)
    return rp.vals[_rper(period) > length(rp.vals) ? end : _rper(period)][_period(period)]
end

function _value_lookup(::NoReprIndex, rp::RepresentativeProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a representative profile",
    )
end

function Base.getindex(
    rp::RepresentativeProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return _value_lookup(RepresentativeIndexable(T), rp, period)
end

"""
    StrategicStochasticProfile(vals::Vector{<:Vector{P}}) where {T, P<:TimeProfile{T}}
    StrategicStochasticProfile(vals::Vector{<:Vector})

Time profile with a separate time profile for each strategic node in a [`TwoLevelTree`](@ref)
structure.

If too few profiles are provided, the last given profile will be repeated, both for strategic
periods and branches within a strategic period.

## Example
```julia
 # The same value in each strategic period and branch
profile = StrategicStochasticProfile([[1], [21, 22]])
# Varying values in each strategic period and branch
profile = StrategicStochasticProfile([
    [OperationalProfile([11, 12])],
    [OperationalProfile([21, 22]), OperationalProfile([31, 32])]
])
```
"""
struct StrategicStochasticProfile{T,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{<:Vector{P}}
end
function StrategicStochasticProfile(vals::Vector{<:Vector{T}}) where {T}
    if T <: Array
        throw(
            ArgumentError(
                "It is not possible to use a `Vector{<:Vector{<:Array}}` as input " *
                "to a `StrategicStochasticProfile`.",
            ),
        )
    else
        return StrategicStochasticProfile([
            [FixedProfile(v_2) for v_2 in v_1] for v_1 in vals
        ])
    end
end
function StrategicStochasticProfile(vals::Vector{<:Vector{T}}) where {T<:TimeProfile}
    ET = promote_type((profilevaluetype(v_2) for v_1 in vals for v_2 in v_1)...)
    return StrategicStochasticProfile([_internal_convert.(ET, v) for v in vals])
end

function _internal_convert(::Type{T}, ssp::StrategicStochasticProfile{S}) where {T,S}
    return StrategicStochasticProfile([_internal_convert.(T, v) for v in ssp.vals])
end

function _value_lookup(::HasStratTreeIndex, ssp::StrategicStochasticProfile, period)
    sp_prof = ssp.vals[_strat_per(period) > length(ssp.vals) ? end : _strat_per(period)]
    branch_prof = sp_prof[_branch(period) > length(sp_prof) ? end : _branch(period)]
    return branch_prof[_period(period)]
end

function _value_lookup(::NoStratTreeIndex, ssp::StrategicStochasticProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a strategic stochastic profile",
    )
end

function Base.getindex(
    ssp::StrategicStochasticProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return _value_lookup(StrategicTreeIndexable(T), ssp, period)
end

Base.getindex(TP::TimeProfile, inds...) = [TP[i] for i in inds]

function Base.getindex(
    TP::TimeProfile,
    inds::Vector{T},
) where {T<:Union{TimePeriod,TimeStructurePeriod}}
    return [TP[i] for i in inds]
end
function Base.getindex(
    TP::TimeProfile,
    ts::T,
) where {T<:Union{TimeStructure,TimeStructInnerIter,TimeStructOuterIter}}
    return [TP[per] for per in ts]
end

function Base.getindex(TP::TimeProfile, inds::Any)
    return error("Type $(typeof(inds)) can not be used as index for a $(typeof(TP))")
end

import Base: +, -, *, /
+(a::FixedProfile{T}, b::Number) where {T} = FixedProfile(a.val + b)
function +(a::OperationalProfile{T}, b::Number) where {T}
    return OperationalProfile(a.vals .+ b)
end
function +(a::StrategicProfile{T}, b::Number) where {T}
    return StrategicProfile(a.vals .+ b)
end
function +(a::ScenarioProfile{T}, b::Number) where {T}
    return ScenarioProfile(a.vals .+ b)
end
function +(a::RepresentativeProfile{T}, b::Number) where {T}
    return RepresentativeProfile(a.vals .+ b)
end
+(a::Number, b::TimeProfile{T}) where {T} = b + a
-(a::FixedProfile{T}, b::Number) where {T} = FixedProfile(a.val - b)
function -(a::OperationalProfile{T}, b::Number) where {T}
    return OperationalProfile(a.vals .- b)
end
function -(a::StrategicProfile{T}, b::Number) where {T}
    return StrategicProfile(a.vals .- b)
end
function -(a::ScenarioProfile{T}, b::Number) where {T}
    return ScenarioProfile(a.vals .- b)
end
function -(a::RepresentativeProfile{T}, b::Number) where {T}
    return RepresentativeProfile(a.vals .- b)
end

*(a::FixedProfile{T}, b::Number) where {T} = FixedProfile(a.val .* b)
function *(a::OperationalProfile{T}, b::Number) where {T}
    return OperationalProfile(a.vals .* b)
end
function *(a::StrategicProfile{T}, b::Number) where {T}
    return StrategicProfile(a.vals .* b)
end
function *(a::ScenarioProfile{T}, b::Number) where {T}
    return ScenarioProfile(a.vals .* b)
end
function *(a::RepresentativeProfile{T}, b::Number) where {T}
    return RepresentativeProfile(a.vals .* b)
end

*(a::Number, b::TimeProfile{T}) where {T} = b * a
/(a::FixedProfile{T}, b::Number) where {T} = FixedProfile(a.val / b)
function /(a::OperationalProfile{T}, b::Number) where {T}
    return OperationalProfile(a.vals ./ b)
end
function /(a::StrategicProfile{T}, b::Number) where {T}
    return StrategicProfile(a.vals ./ b)
end
function /(a::ScenarioProfile{T}, b::Number) where {T}
    return ScenarioProfile(a.vals ./ b)
end
function /(a::RepresentativeProfile{T}, b::Number) where {T}
    return RepresentativeProfile(a.vals ./ b)
end
