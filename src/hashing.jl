# Hashing of periods
#
# Periods are often used as keys of dictionaries, e.g. in JuMP containers indexed by
# nodes and time periods.  Periods of bits types (e.g. `OperationalPeriod`) keep
# Julia's default hash, which hashes their bytes and is fast.  For the others (e.g.
# `StrategicPeriod`, which carries along its time structure in the field
# `operational`), the default hash is the generic hash of the object, which is about
# ten times slower.  For those, the methods below hash the type's name and the fields
# that identify a period instead: its numbers, dates and nested periods.  Fields
# holding a time structure, a time profile, or of type `Any` (e.g. the parent of a
# strategic node) are left out.
#
# Equality is unchanged (the default `===`).  Values that are `===` have `===`
# fields and hence the same hash, so `isequal(a, b)` still implies
# `hash(a) == hash(b)`; leaving fields out can only make two periods hash alike.

function _hashed_field(::Type{F}) where {F}
    F === Any && return false
    F <: TimeStructurePeriod && return true          # (hashed by the methods below)
    return !(F <: Union{TimeStructure,TimeStructInnerIter,TimeStructOuterIter,TimeProfile})
end

@generated function _hash_period(x, h::UInt)
    isbitstype(x) && return :(invoke(hash, Tuple{Any,UInt}, x, h))
    ex = :(hash($(QuoteNode(nameof(x))), h))
    for (f, F) in zip(fieldnames(x), fieldtypes(x))
        _hashed_field(F) || continue
        ex = :(hash(getfield(x, $(QuoteNode(f))), $ex))
    end
    return ex
end

Base.hash(t::TimePeriod, h::UInt) = _hash_period(t, h)
Base.hash(t::TimeStructurePeriod, h::UInt) = _hash_period(t, h)
Base.hash(t::PeriodPartition, h::UInt) = _hash_period(t, h)
