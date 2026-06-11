# Add generic partition duration type
abstract type AbstractOpScenPart{T} <: PartitionDuration{T} end

ScenarioIndexable(::Type{<:AbstractOpScenPart}) = HasScenarioIndex()
_opscen(pd::AbstractOpScenPart) = pd.scen
