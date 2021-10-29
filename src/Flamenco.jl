module Flamenco

import Sockets

include("Server.jl")
include("Writer.jl")


"""
    close_server()

Stop Flamenco server
"""
function close_server()
    Server.close()
end


"""
    start_server(
        f::Function,
        host::Union{Sockets.IPAddr, String}=Sockets.localhost,
        port::Int64=8000
    ) :: Server.Request

Start Flamenco server on specified host/port
`f` is function that parsed `request` is forwarded to
"""
function start_server(
    f::Function,
    host::Union{Sockets.IPAddr, String}=Sockets.localhost,
    port::Int64=8000
) :: Server.Request
    request::Server.Request = Server.Request("", "", Dict(), "")

    try
        request = Server.start(f, host, port)
    catch e
        if e isa InterruptException
            @warn "Server interrupted"
        else
            rethrow(e)
        end
    end

    return request
end


"""
    write_response(status_code::Int16, headers::Dict{String, String}; body::String) :: String

Return HTTP response String
"""
function write_response(status_code::Int16, headers::Dict{String, String}; body::String) :: String
    response::String = ""

    if length(body) > 0
        response = Writer.write(status_code, headers; body=body)
    else
        response = Writer.write(status_code, headers)
    end

    return response
end

end
