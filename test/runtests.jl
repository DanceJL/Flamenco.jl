#!/usr/bin/env julia

using Test, SafeTestsets


@time begin
@time @safetestset "CRUD" begin include("crud_test.jl") end
@time @safetestset "Header" begin include("header_test.jl") end
@time @safetestset "Error" begin include("error_test.jl") end
end
