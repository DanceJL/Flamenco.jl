import Flamenco
import HTTP
import JSON

include("./request.jl")


function make_and_test_request_delete(headers::Vector{Pair{String,String}}) :: Nothing
    r = HTTP.request("DELETE", "http://127.0.0.1:8000/", headers)
    parse_and_test_request(r, 200, headers, 15, true, false, Dict("Success" => 200))
end


function make_and_test_request_get(headers::Vector{Pair{String,String}}) :: Nothing
    r = HTTP.request("GET", "http://127.0.0.1:8000/", headers)
    parse_and_test_request(r, 200, headers, 230, false, true)
end


function make_and_test_request_options(headers::Vector{Pair{String,String}}) :: Nothing
    r = HTTP.request("OPTIONS", "http://127.0.0.1:8000/", headers)
    parse_and_test_request(r, 200, headers, 2, true, false, Dict())
    compare_http_header(r.headers, "Allow", "POST")
    compare_http_header(r.headers, "Access-Control-Allow-Methods", "POST")
    compare_http_header(r.headers, "Access-Control-Allow-Headers", "X-PINGOTHER, Content-Type")
end


function make_and_test_request_put(headers::Vector{Pair{String,String}}, payload::Dict, content_length::Int64) :: Nothing
    r = HTTP.request("PUT", "http://127.0.0.1:8000/", headers, JSON.json(payload))
    parse_and_test_request(r, 200, headers, content_length, true, false, payload)
end


function make_and_test_request_post(headers::Vector{Pair{String,String}}, payload::Dict, content_length::Int64) :: Nothing
    r = HTTP.request("POST", "http://127.0.0.1:8000/", headers, JSON.json(payload))
    parse_and_test_request(r, 200, headers, content_length, true, false, payload)
end

#############


function routes(; request_headers::Dict{String, String}, request_method::String, request_path::String, request_payload::String) :: String
    body::String = "a"
    headers::Dict{String, String} = Dict()
    status_code::Int16 = 404

    if (request_path=="/")
        status_code = 200
        delete!(request_headers, "Content-Length")
        delete!(request_headers, "Date")

        if (request_method=="DELETE")
            headers = merge(
                request_headers,
                Dict("Content-Type" => "application/json")
            )
            body = JSON.json(Dict(
                "Success" => 200
            ))
        elseif (request_method=="GET")
            headers = merge(
                request_headers,
                Dict("Content-Type" => "text/html; charset=UTF-8")
            )
            body = """<!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta http-equiv="Content-type" content="text/html; charset=utf-8">
                    <title>Flamenco</title>
                </head>
                <body>
                    <div>Content ...</div>
                </body>
            </html>
            """
        elseif (request_method=="OPTIONS")
            headers = merge(
                request_headers,
                Dict(
                    "Allow" => "POST",
                    "Access-Control-Allow-Methods" => "POST",
                    "Access-Control-Allow-Headers" => "X-PINGOTHER, Content-Type",
                    "Content-Type" => "application/json"
                )
            )
            body = JSON.json(Dict())
        elseif (request_method=="PUT" || request_method=="POST")
            headers = merge(
                request_headers,
                Dict(
                    "Content-Type" => "application/json"
                )
            )
            body = request_payload
        end
    end

    return Flamenco.write_response(status_code, headers; body=body)
end


function server_close() :: Nothing
    Flamenco.close_server()
end


function server_start()
    @async Flamenco.start_server("127.0.0.1", 8000) do request::Flamenco.Server.Request
        routes(; request_headers=request.headers, request_method=request.method, request_path=request.target, request_payload=request.body)
    end
end
