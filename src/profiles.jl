abstract type TimeProfile{T} end

"""
    FixedProfile(val<:Number)

Time profile with a constant value for all time periods.

## Example
```julia
profile = FixedProfile(5)
```
"""
struct FixedProfile{T<:Number} <: TimeProfile{T}
    val::T
end

function Base.getindex(
    fp::FixedProfile,
    _::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return fp.val
end

"""
    OperationalProfile(vals::Vector{T}) where {T<:Number}

Time profile with a value that varies with the operational time period.

If too few values are provided, the last provided value will be repeated.

## Example
```julia
profile = OperationalProfile([1, 2, 3, 4, 5])
```
"""
struct OperationalProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{T}
end

function Base.getindex(
    op::OperationalProfile,
    i::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return op.vals[_oper(i) > length(op.vals) ? end : _oper(i)]
end

"""
    StrategicProfile(vals::Vector{P}) where {T<:Number, P<:TimeProfile{T}}
    StrategicProfile(vals::Vector{<:Number})

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
struct StrategicProfile{T<:Number,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end
function StrategicProfile(vals::Vector{<:Number})
    return StrategicProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasStratIndex, sp::StrategicProfile, period)
    return sp.vals[_strat_per(period) > length(sp.vals) ? end :
                   _strat_per(period)][period]
end

function _value_lookup(::NoStratIndex, sp::StrategicProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a strategic profile",
    )
end

function Base.getindex(
    sp::StrategicProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(StrategicIndexable(T), sp, period)
end

"""
    ScenarioProfile(vals::Vector{P}) where {T<:Number, P<:TimeProfile{T}}
    ScenarioProfile(vals::Vector{<:Number})

Time profile with a separate time profile for each scenario.

If too few profiles are provided, the last given profile will be repeated.

## Example
```julia
# Varying values in each operational scenario
profile = ScenarioProfile([OperationalProfile([1, 2]), OperationalProfile([3, 4, 5])])
 # The same value in each operational scenario
profile = ScenarioProfile([1, 2, 3, 4, 5])
```
"""
struct ScenarioProfile{T<:Number,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end
function ScenarioProfile(vals::Vector{<:Number})
    return ScenarioProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasScenarioIndex, sp::ScenarioProfile, period)
    return sp.vals[_opscen(period) > length(sp.vals) ? end : _opscen(period)][period]
end

function _value_lookup(::NoScenarioIndex, sp::ScenarioProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a scenario profile",
    )
end

function Base.getindex(
    sp::ScenarioProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(ScenarioIndexable(T), sp, period)
end

"""
    RepresentativeProfile(vals::Vector{P}) where {T<:Number, P<:TimeProfile{T}}
    RepresentativeProfile(vals::Vector{<:Number})

Time profile with a separate time profile for each representative period.

If too few profiles are provided, the last given profile will be repeated.

## Example
```julia
# Varying values in each representative period
profile = RepresentativeProfile([OperationalProfile([1, 2]), OperationalProfile([3, 4, 5])])
 # The same value in each representative period
profile = RepresentativeProfile([1, 2, 3, 4, 5])
```
"""
struct RepresentativeProfile{T<:Number,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end
function RepresentativeProfile(vals::Vector{<:Number})
    return RepresentativeProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasReprIndex, rp::RepresentativeProfile, period)
    return rp.vals[_rper(period) > length(rp.vals) ? end : _rper(period)][period]
end

function _value_lookup(::NoReprIndex, rp::RepresentativeProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a representative profile",
    )
end

function Base.getindex(
    rp::RepresentativeProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(RepresentativeIndexable(T), rp, period)
end

struct StrategicStochasticProfile{T} <: TimeProfile{T}
    vals::Vector{Vector{T}}
end
function Base.getindex(ssp::StrategicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)]
end

struct DynamicStochasticProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{<:Vector{<:TimeProfile{T}}}
end
function Base.getindex(ssp::DynamicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)][i]
end

Base.getindex(TP::TimeProfile, inds...) = [TP[i] for i in inds]

function Base.getindex(
    TP::TimeProfile,
    inds::Vector{T},
) where {T<:Union{TimePeriod,TimeStructure}}
    return [TP[i] for i in inds]
end

function Base.getindex(TP::TimeProfile, inds::Any)
    return error(
        "Type $(typeof(inds)) can not be used as index for a $(typeof(TP))",
    )
end

import Base: +, -, *, /
+(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val + b)
function +(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .+ b)
end
function +(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .+ b)
end
function +(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .+ b)
end
function +(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .+ b)
end
+(a::Number, b::TimeProfile{T}) where {T<:Number} = b + a
-(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val - b)
function -(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .- b)
end
function -(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .- b)
end
function -(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .- b)
end
function -(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .- b)
end

*(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val .* b)
function *(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .* b)
end
function *(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .* b)
end
function *(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .* b)
end
function *(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .* b)
end

*(a::Number, b::TimeProfile{T}) where {T<:Number} = b * a
/(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val / b)
function /(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals ./ b)
end
function /(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals ./ b)
end
function /(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals ./ b)
end
function /(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals ./ b)
end
