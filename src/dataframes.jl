using .DataFrames

function expand_dataframe!(df::DataFrame, periods)
    for col in eachcol(df)
        
        if eltype(col) <: StratNode
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :branch] = [_branch(t) for t in col]
        elseif eltype(col) <: OperationalPeriod
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :op_scenario] = [_opscen(t) for t in col]
            df[!, :oper_period] = [_oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_oper_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_oper_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: SimplePeriod
            df[!, :oper_period] = [t.op for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: ScenarioPeriod
            df[!, :op_scenario] = [_opscen(t) for t in col]
            df[!, :oper_period] = [_oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: StrategicPeriod
            df[!, :strategic_period] = [_strat_per(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_time(t, periods) for t in col]
            df[!, :end_time] = [end_time(t, periods) for t in col]
        end
    end
end
