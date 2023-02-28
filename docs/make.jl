using Cropbox
using Documenter

makedocs(
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = ["assets/favicon.ico"],
        analytics = "UA-192782823-1",
    ),
    sitename = "Cropbox.jl",
    pages = [
        "Introduction" => [
            "Cropbox" => "index.md",
            "Installation" => "installation.md"
        ],
        "Tutorials" => [
            "Getting started with Julia" => "tutorials/julia.md",
            "Getting started with Cropbox" => "tutorials/cropbox.md",
            "Making a model" => "tutorials/makingamodel.md",
            "Using an existing model" => "tutorials/usingamodel.md",
        ],
        "Manual" => map(
            file -> "guide/$(file)", [
                "System" => "guide/system.md",
                "Variable" => "guide/variable.md",
                "Configuration" => "guide/configuration.md",
                "Simulation" => "guide/simulation.md",
                "Visualization" => "guide/visualization.md",
                "Inspection" => "guide/inspection.md",
                ]
            ),
        "Gallery" => "gallery.md",
        "Reference" => [
            "Index" => "reference/index.md",
            "Declaration" => "reference/declaration.md",
            "Simulation" => "reference/simulation.md",
            "Visualization" => "reference/visualization.md",
            "Inspection" => "reference/inspection.md",
        ],
        "Frequently Asked Questions" => "faq.md"
    ]
)

deploydocs(
    repo = "github.com/junhyukjeon/Cropbox.jl.git",
    devbranch = "documentation",
)
