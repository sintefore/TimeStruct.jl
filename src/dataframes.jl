using .DataFrames

function expand_dataframe(df::DataFrame)
    for col in eachcol(df)
        if eltype(col) == TreeNode
            df[!,:strategic_period] = [strat_per(t) for t in col] 
            df[!,:branch] = [branch(t) for t in col] 
        end
    end
    return df
end