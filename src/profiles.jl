# Defintion of the main types for time profiles
abstract type TimeProfile{T} end

" Definition of the individual time profiles

FixedProfile:
	Fixed profile independent of strategic and operational period

OperationalProfile:
    Profile varying with operational period
	
StrategicProfile:
	Profile varying with strategic period

DynamicProfile:
    Variations in both strategic and operational horizons

ScenarioProfile:
    Profile with multiple scenarios
"

struct FixedProfile{T} <: TimeProfile{T}
    vals::T
end
Base.getindex(fp::FixedProfile, i::TimePeriod) = fp.vals

struct OperationalProfile{T} <: TimeProfile{T}
    vals::Array{T}
end
Base.getindex(ofp::OperationalProfile, i::TimePeriod) = ofp.vals[mod(i.op - 1, length(ofp.vals)) + 1]

struct StrategicProfile{T} <: TimeProfile{T}
    vals::Array{T}
end
Base.getindex(sfp::StrategicProfile, i::TimePeriod) = sfp.vals[isnothing(strat_per(i)) ? 1 : strat_per(i)]

struct DynamicProfile{T} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
Base.getindex(dp::DynamicProfile, i::TimePeriod) = dp.vals[isnothing(strat_per(i)) ? 1 : strat_per(i)][i]

struct ScenarioProfile{T} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
Base.getindex(sfp::ScenarioProfile, i::TimePeriod) = sfp.vals[isnothing(opscen(i)) ? 1 : opscen(i)][i]

function ScenarioProfile(vals::Vector{Vector{T}}) where T <: Number
    v = Vector{OperationalProfile{T}}()
    for scv in vals
        push!(v, OperationalProfile{T}(scv))
    end
    return ScenarioProfile(v)
end


import Base:+,-,*,/
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