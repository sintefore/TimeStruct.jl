# Add generic partition duration type
abstract type AbstractReprPart{T} <: PartitionDuration{T} end

RepresentativeIndexable(::Type{<:AbstractReprPart}) = HasReprIndex()
_rper(pd::AbstractReprPart) = pd.rp
