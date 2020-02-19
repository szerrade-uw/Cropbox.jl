using Cropbox
using Test

@testset "cropbox" begin
    @testset "framework" begin
        include("macro.jl")
        include("state.jl")
        include("system.jl")
        include("unit.jl")
        include("config.jl")
        include("tool.jl")
    end

    @testset "application" begin
        include("lotka_volterra.jl")
        include("root/root.jl")
        include("garlic/garlic.jl")
        include("photosynthesis.jl")
    end
end
