include("utils/main.jl")


server_start()

@testset "Space before Header colon" begin
    r = HTTP.request("GET", "http://127.0.0.1:8000/", ["a " => "b"])
    parse_and_test_request(r, 200, ["a" => "b"], 230, false, true)
end

@testset "Space after Header colon" begin
    r = HTTP.request("GET", "http://127.0.0.1:8000/", ["a" => " b"])
    parse_and_test_request(r, 200, ["a" => "b"], 230, false, true)
end

server_close()
