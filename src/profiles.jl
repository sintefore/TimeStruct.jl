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
_internal_convert(::Type{T}, fp::FixedProfile{T}) where {T} = fp
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
_internal_convert(::Type{T}, op::OperationalProfile{T}) where {T} = op
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

_internal_convert(::Type{T}, sp::StrategicProfile{T}) where {T} = sp
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

_internal_convert(::Type{T}, sp::ScenarioProfile{T}) where {T} = sp
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

_internal_convert(::Type{T}, rp::RepresentativeProfile{T}) where {T} = rp
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

_internal_convert(::Type{T}, ssp::StrategicStochasticProfile{T}) where {T} = ssp
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

# Profile printing

_truncate(io::IO, n, max_elems) = get(io, :limit, false) && n > max_elems

function _print_values(io::IO, vals; max_elems = 10)
    n = length(vals)
    if !_truncate(io, n, max_elems)
        return join(io, vals, ", ")
    end
    nshow = round(Int, max_elems / 2)
    join(io, vals[1:nshow], ", ")
    print(io, "  …  ")
    return join(io, vals[(end-nshow+1):end], ", ")
end

_layers(vals::Vector) = maximum(_layers(v) for v in vals)
_layers(vals::Vector{<:Vector}) = maximum(_layers(v) for v in vals) + 1
_layers(p::TimeProfile) = _layers(p.vals) + 1
_layers(p::FixedProfile) = 1
_layers(p::OperationalProfile) = 1

function _print_lines(io::IO, vals, indent_level)
    for (i, v) in enumerate(vals)
        i > 1 && println(io)
        _print_profile(io, v, indent_level)
    end
end

function _print_values_indent(io::IO, vals, indent_level; max_lines = 5)
    n = length(vals)
    m = _layers(vals)
    nshow = round(Int, max_lines / 2 - m + 1)
    nhead = max(nshow, 2)
    ntail = max(nshow, 1)
    # Only truncate when at least one element is hidden
    if !_truncate(io, n, max(max_lines - 2m + 2, nhead + ntail))
        return _print_lines(io, vals, indent_level)
    end
    _print_lines(io, vals[1:nhead], indent_level)
    print(io, "\n", _indent(indent_level), "⋮\n")
    return _print_lines(io, vals[(end-ntail+1):end], indent_level)
end

_indent(n) = " "^(n * 2)
_length(p::TimeProfile) = "$(length(p.vals))-element "
_length(p::FixedProfile) = ""

_profile_name(p::TimeProfile) = _length(p) * "$(typeof(p).name.name)"
_profile_name(v::Vector) = "$(length(v))-element Vector"

# Separator between the summary and the values in the multi-line display
_summary_sep(p::TimeProfile) = ":"
_summary_sep(p::Union{FixedProfile,OperationalProfile}) = ": "

function _print_profile(io::IO, p, indent_level)
    print(io, _indent(indent_level), _profile_name(p))
    return _print_body(io, p, indent_level)
end

_print_body(io::IO, p::TimeProfile, indent_level) = _print_body(io, p.vals, indent_level)
function _print_body(io::IO, vals::Vector, indent_level)
    print(io, "\n", _indent(indent_level), "[\n")
    _print_values_indent(io, vals, indent_level + 1)
    return print(io, "\n", _indent(indent_level), "]")
end
_print_body(io::IO, fp::FixedProfile, indent_level) = print(io, "[", fp.val, "]")
function _print_body(io::IO, op::OperationalProfile, indent_level)
    print(io, "[")
    _print_values(io, op.vals)
    return print(io, "]")
end

# Single-line representation used by the two-argument `show`
_show_inline(io::IO, val) = show(io, val)
function _show_inline(io::IO, fp::FixedProfile)
    print(io, "FixedProfile(")
    show(io, fp.val)
    return print(io, ")")
end
function _show_inline(io::IO, p::TimeProfile)
    print(io, typeof(p).name.name, "(")
    _show_inline(io, p.vals)
    return print(io, ")")
end
function _show_inline(io::IO, vals::Vector; max_elems = 10)
    n = length(vals)
    print(io, "[")
    if _truncate(io, n, max_elems)
        nshow = round(Int, max_elems / 2)
        _join_inline(io, vals[1:nshow])
        print(io, "  …  ")
        _join_inline(io, vals[(end-nshow+1):end])
    else
        _join_inline(io, vals)
    end
    return print(io, "]")
end

function _join_inline(io::IO, vals)
    for (i, v) in enumerate(vals)
        i > 1 && print(io, ", ")
        _show_inline(io, v)
    end
end

function Base.summary(io::IO, p::TimeProfile{T}) where {T}
    return print(io, _length(p) * "$(typeof(p).name.name) with eltype $T")
end

function Base.show(io::IO, p::TimeProfile)
    if get(io, :compact, false)
        return summary(io, p)
    end
    return _show_inline(io, p)
end

function Base.show(io::IO, ::MIME"text/plain", p::TimeProfile)
    summary(io, p)
    print(io, _summary_sep(p))
    # Show values with reduced precision, as Base does for array elements
    return _print_body(IOContext(io, :compact => true), p, 0)
end
