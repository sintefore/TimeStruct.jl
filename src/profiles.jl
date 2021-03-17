abstract type TimeProfile end

struct FixedProfile{T} <: TimeProfile
    val::T
end

Base.getindex(fp::FixedProfile, i) = fp.val

struct StrategicFixedProfile{T} <: TimeProfile
    vals::Array{T}
end

Base.getindex(sfp::StrategicFixedProfile, i::OperationalPeriod) = sfp.vals[i.sp]

struct DynamicProfile{T} <: TimeProfile
    vals::Array{T,2}
end

Base.getindex(dp::DynamicProfile, i) = dp.vals[i.sp, i.op]