import Sockets
include("utils/main.jl")


server_start()


@testset "404" begin
    try
        HTTP.request("GET", "http://127.0.0.1:8000/a", []; retry=false)
    catch e
        @test e isa HTTP.ExceptionRequest.StatusError
    end
end


server_close()
