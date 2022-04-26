using .DataFrames

function expand_dataframe!(df::DataFrame)
    for col in eachcol(df)
        if eltype(col) <: StratNode
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :branch] = [_branch(t) for t in col]
        elseif eltype(col) <: OperationalPeriod
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :op_scenario] = [_opscen(t) for t in col]
            df[!, :oper_period] = [_oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = vcat(0, cumsum(df[!, :duration][1:(end-1)]))
        elseif eltype(col) <: SimplePeriod
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :oper_period] = [t.op for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = vcat(0, cumsum(df[!, :duration][1:(end-1)]))
        elseif eltype(col) <: ScenarioPeriod
            df[!, :op_scenario] = [_opscen(t) for t in col]
            df[!, :oper_period] = [_oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = vcat(0, cumsum(df[!, :duration][1:(end-1)]))
        elseif eltype(col) <: StrategicPeriod
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = vcat(0, cumsum(df[!, :duration][1:(end-1)]))
        end
    end
end
