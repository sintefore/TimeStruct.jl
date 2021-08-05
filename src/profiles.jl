# Defintion of the main types for time profiles
abstract type TimeProfile end

" Definition of the individual time profiles

FixedProfile:
	Fixed profile independent of strategic and operational period

OperationalFixedProfile:
    Fixed strategic profile with varying operational profiles
	
StrategicFixedProfile:
	Fixed operational profile with varying strategic profiles

DynamicProfile:
    Variations in both strategic and operational horizons
"

struct FixedProfile{T} <: TimeProfile
    val::T
end
Base.getindex(fp::FixedProfile, i) = fp.val

struct OperationalFixedProfile{T} <: TimeProfile
    vals::Array{T}
end
Base.getindex(ofp::OperationalFixedProfile, i::TimePeriod{UniformTwoLevel}) = ofp.vals[i.op]

struct StrategicFixedProfile{T} <: TimeProfile
    vals::Array{T}
end
Base.getindex(sfp::StrategicFixedProfile, i::TimePeriod{UniformTwoLevel}) = sfp.vals[i.sp]
# Base.getindex(sfp::StrategicFixedProfile, i::OperationalPeriod) = sfp.vals[i.sp]
# Base.getindex(sfp::StrategicFixedProfile, i::StrategicPeriod) = sfp.vals[i.sp]

struct DynamicProfile{T} <: TimeProfile
    vals::Array{T,2}
end
Base.getindex(dp::DynamicProfile, i::TimePeriod{UniformTwoLevel}) = dp.vals[i.sp, i.op]