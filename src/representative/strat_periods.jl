"""
    StratReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single representative period supporting iteration over its
time periods. It is created when iterating through [`StratReprPeriods`](@ref).
"""
struct StratReprPeriod{T,OP<:TimeStructure{T}} <:
       AbstractRepresentativePeriod{T}
    sp::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    operational::OP
end

_rper(rp::StratReprPeriod) = rp.rp
_strat_per(rp::StratReprPeriod) = rp.sp

multiple(rp::StratReprPeriod, t::OperationalPeriod) = t.multiple / rp.mult_sp
mult_repr(rp::StratReprPeriod) = rp.mult_rp
mult_strat(rp::StratReprPeriod) = rp.mult_sp

StrategicIndexable(::Type{<:StratReprPeriod}) = HasStratIndex()

# Provide a constructor to simplify the design
function OperationalPeriod(rp::StratReprPeriod, per)
    mult = mult_strat(rp) * multiple(per)
    return OperationalPeriod(_strat_per(rp), per, mult)
end

function Base.show(io::IO, rp::StratReprPeriod)
    return print(io, "sp$(_strat_per(rp))-rp$(_rper(rp))")
end

# Add basic functions of iterators
Base.length(rp::StratReprPeriod) = length(rp.operational)
Base.eltype(_::Type{StratReprPeriod{T,OP}}) where {T,OP} = OperationalPeriod
function Base.iterate(rp::StratReprPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(rp.operational) :
        iterate(rp.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(rp, next[1]), next[2]
end
function Base.getindex(rp::StratReprPeriod, index::Int)
    per = rp.operational[index]
    return OperationalPeriod(rp, per)
end
function Base.eachindex(rp::StratReprPeriod)
    return eachindex(rp.operational)
end
function Base.last(rp::StratReprPeriod)
    per = last(rp.operational)
    return OperationalPeriod(rp, per)
end

"""
    StratReprPeriods{OP}

Type for iterating through the individual representative periods of a
[`StrategicPeriod`](@ref) time structure. It is automatically created through the function
[`repr_periods`](@ref).
"""
struct StratReprPeriods{OP}
    sp::Int
    mult_sp::Float64
    repr::OP
end

"""
When the `TimeStructure` is a [`StrategicPeriod`](@ref), `repr_periods` returns the iterator
[`StratReprPeriods`](@ref).
"""
function repr_periods(sp::StrategicPeriod{S,T,OP}) where {S,T,OP}
    return StratReprPeriods(_strat_per(sp), mult_strat(sp), repr_periods(sp.operational))
end

# Provide a constructor to simplify the design
function StratReprPeriod(rpers::StratReprPeriods, state, per)
    return StratReprPeriod(rpers.sp, state, rpers.mult_sp, mult_repr(per), per)
end

# Add basic functions of iterators
Base.length(rpers::StratReprPeriods) = length(rpers.repr)
function Base.iterate(rpers::StratReprPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(rpers.repr) :
        iterate(rpers.repr, state[1])
    isnothing(next) && return nothing

    return StratReprPeriod(rpers, state[2], next[1]), (next[2], state[2] + 1)
end
function Base.getindex(rpers::StratReprPeriods, index::Int)
    return StratReprPeriod(rpers, index)
end
function Base.eachindex(rpers::StratReprPeriods)
    return eachindex(rpers.repr)
end
function Base.last(rpers::StratReprPeriods)
    per = last(rpers.repr)
    return StratReprPeriod(rpers, _rper(per), per)
end

"""
When the `TimeStructure` is a [`SingleStrategicPeriod`](@ref), `repr_periods` returns the
correct behavior based on the substructure.
"""
repr_periods(ts::SingleStrategicPeriod) = repr_periods(ts.ts)
"""
When the `TimeStructure` is a [`TwoLevel`](@ref), `repr_periods` returns an `Array` of
all [`StratReprPeriod`](@ref)s.
"""
function repr_periods(ts::TwoLevel)
    return collect(
        Iterators.flatten(repr_periods(sp) for sp in strategic_periods(ts)),
    )
end
