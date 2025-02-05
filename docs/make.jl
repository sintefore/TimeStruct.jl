using Documenter
using Literate
using TimeStruct

# Literate on tutorial folder
for (root, dir, files) in walkdir(joinpath(@__DIR__, "src", "tutorials"))
    for file in files
        if endswith(file, ".jl")
            Literate.markdown(joinpath(root, file), root; documenter = true)
        end
    end
end

pages = [
    "Introduction" => "index.md",
    "Tutorials" => [
        "Battery sizing" => "tutorials/battery_sizing.md",
    ],
    "Showcases" => [
        "EnergyModelsX" => "showcases/emx.md",
    ],
    "Manual" => [
        "Operational time structures" => "manual/basic.md",
        "Multi-horizon" => "manual/multi.md",
        "Time profiles" => "manual/profiles.md",
        "Iteration utilities" => "manual/iteration.md",
        "Discounting" => "manual/discount.md",
    ],
    "Contribute" => "contribute.md",
    "API reference" => "reference/api.md",
    "Internal reference" => "reference/internal.md",
]

DocMeta.setdocmeta!(TimeStruct, :DocTestSetup, :(using TimeStruct); recursive = true)

Documenter.makedocs(
    sitename = "TimeStruct",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
    ),
    doctest = false,
    modules = [TimeStruct],
    pages = pages,
)

Documenter.deploydocs(; repo = "github.com/sintefore/TimeStruct.jl.git")
