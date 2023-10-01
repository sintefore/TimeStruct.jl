using Documenter, TimeStruct

pages = [
    "Introduction" => "index.md",
    "Manual" => [
        "Operational time structures" => "manual/basic.md",
        "Multi-horizon" => "manual/multi.md",
        "Iteration utilities" => "manual/iteration.md",
        "Discounting" => "manual/discount.md"
    ],
    "API reference" => "reference/api.md"
]

makedocs(
    sitename="TimeStruct.jl", 
    repo="https://gitlab.sintef.no/julia-one-sintef/timestruct.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://julia-one-sintef.pages.sintef.no/timestruct.jl/",
        edit_link="main",
        assets=String[],
    ),
    #modules = [TimeStruct],
    pages = pages
)