abstract type TimeProfile{T} end

struct FixedProfile{T<:Number} <: TimeProfile{T}
    vals::T
end
function FixedProfile(val::T, u::Unitful.Units) where {T}
    return FixedProfile(Unitful.Quantity(val, u))
end
Base.getindex(fp::FixedProfile, _::TimePeriod) = fp.vals

struct OperationalProfile{T<:Number} <: TimeProfile{T}
    vals::Array{T}
end
function OperationalProfile(val::T, u::Unitful.Units) where {T}
    return OperationalProfile(Unitful.Quantity.(val, u))
end
function Base.getindex(ofp::OperationalProfile, i::TimePeriod)
    return ofp.vals[mod1(_oper(i), length(ofp.vals))]
end

struct StrategicProfile{T<:Number} <: TimeProfile{T}
    vals::Array{T}
end
function StrategicProfile(val::T, u::Unitful.Units) where {T}
    return StrategicProfile(Unitful.Quantity.(val, u))
end
function Base.getindex(sfp::StrategicProfile, i::TimePeriod)
    return sfp.vals[_strat_per(i)]
end

struct DynamicProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
function Base.getindex(dp::DynamicProfile, i::TimePeriod)
    return dp.vals[_strat_per(i)][i]
end

struct ScenarioProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
function Base.getindex(sfp::ScenarioProfile, i::TimePeriod)
    return sfp.vals[_opscen(i)][i]
end

struct StrategicScenarioProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{Vector{<:TimeProfile{T}}}
end
function Base.getindex(ssp::StrategicScenarioProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_opscen(i)][i]
end

function ScenarioProfile(vals::Vector{Vector{T}}) where {T<:Number}
    v = Vector{OperationalProfile{T}}()
    for scv in vals
        push!(v, OperationalProfile{T}(scv))
    end
    return ScenarioProfile(v)
end

struct StrategicStochasticProfile{T<:Number} <: TimeProfile{T}
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

import Base: +, -, *, /
+(a::FixedProfile, b::Number) = FixedProfile(a.vals .+ b)
+(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .+ b)
+(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .+ b)
+(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .+ b)
+(a::Number, b::TimeProfile) = b + a
-(a::FixedProfile, b::Number) = FixedProfile(a.vals .- b)
-(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .- b)
-(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .- b)
-(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .- b)
*(a::FixedProfile, b::Number) = FixedProfile(a.vals .* b)
*(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .* b)
*(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .* b)
*(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .* b)
*(a::Number, b::TimeProfile) = b * a
/(a::FixedProfile, b::Number) = FixedProfile(a.vals ./ b)
/(a::OperationalProfile, b::Number) = OperationalProfile(a.vals ./ b)
/(a::DynamicProfile, b::Number) = DynamicProfile(a.vals ./ b)
/(a::StrategicProfile, b::Number) = StrategicProfile(a.vals ./ b)
