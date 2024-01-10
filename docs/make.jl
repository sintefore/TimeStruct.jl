using Documenter, TimeStruct

pages = [
    "Introduction" => "index.md",
    "Manual" => [
        "Operational time structures" => "manual/basic.md",
        "Multi-horizon" => "manual/multi.md",
        "Time profiles" => "manual/profiles.md",
        "Iteration utilities" => "manual/iteration.md",
        "Discounting" => "manual/discount.md",
    ],
    "API reference" => "reference/api.md",
]

Documenter.makedocs(
    sitename = "TimeStruct",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
    ),
    doctest = false,
    #modules = [TimeStruct],
    pages = pages,
)

Documenter.deploydocs(;
    repo = "github.com/sintefore/TimeStruct.jl.git",
    push_preview = true,
)
