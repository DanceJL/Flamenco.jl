module Server

import BufferedStreams
import Sockets
import ThreadPools

include("parsers/Http1_1.jl")
include("Utils.jl")
include("Writer.jl")


struct Error
    code::Int16
    message::String
end

struct Request
    target::String
    method::String
    headers::Dict{String, String}
    body::String
end


SERVER = nothing


"""
    _handle_connection(buffered_stream::BufferedStreams.BufferedInputStream) :: Tuple{Error, Request}

Forward BufferedInputStream to Http1.1 parser
If error occurs, return Error struct and empty Request struct
"""
function _handle_connection(buffered_stream::BufferedStreams.BufferedInputStream) :: Tuple{Error, Request}
    body::String = ""
    error::Error = Error(0, "")
    headers::Dict{String, String} = Dict()
    method::String = ""
    target::String = ""
    request::Request = Request(target, method, headers, body)

    try
        target, method, headers, body = ParserHttp1_1.parse_request(buffered_stream)
        request = Request(target, method, headers, body)
    catch e
        if method!="" && e isa EOFError
            request = Request(target, method, headers, body)
        elseif contains(string(typeof(e)), "TimeoutError")
            error = Error(408, "Request Timeout")
        elseif contains(string(typeof(e)), "InternalError")
            error = Error(500, sprint(showerror, e))
        else
            error = Error(401, "Bad Request")
        end
    end

    return error, request
end


"""
    close()

Stop listening on Socket
"""
function close()
    Sockets.close(SERVER)
end


"""
    start(f::Function, host::Union{Sockets.IPAddr, String}, port::Integer) :: Request

Listen to incoming requests on separate threads
Write response (execute corresponding Julia function) to Socket, before closing it
"""
function start(f::Function, host::Union{Sockets.IPAddr, String}, port::Integer) :: Request
    error::Error = Error(0, "")
    request::Request = Request("", "", Dict(), "")
    response::String = ""

    global SERVER
    SERVER = Sockets.listen(parse(Sockets.IPAddr, host), port)  # TODO increase backlog=511

    while isopen(SERVER)
        ThreadPools.@bthreads for x in 1:1
            socket = Sockets.accept(SERVER)
            bytes::Vector{UInt8} = readavailable(socket)

            # TODO: Find better way for PUT/POST requests with blank line before body content
            # As simply `bytesavailable` will return 0
            if ( bytes[1:4] == UInt8[0x50, 0x4f, 0x53, 0x54] || bytes[1:3] == UInt8[0x50, 0x55, 0x54] )
                if ( bytes[length(bytes)-3:length(bytes)] == UInt8[0x0d, 0x0a, 0x0d, 0x0a] )
                    bytes = append!(bytes, readavailable(socket))
                end
            end
            buffered_stream = BufferedStreams.BufferedInputStream(bytes)

            try
                error, request = _handle_connection(buffered_stream)
                if error.message != ""
                    response = Writer.write(error.code, request.headers; body=error.message)
                else
                    response = f(request)
                end
            catch e
                error = Error(500, sprint(showerror, e))
                @error "Error handling request" exception=(e, stacktrace(catch_backtrace()))
                if e isa Base.IOError && e.code == -54
                    @warn "Connection reset by peer (ECONNRESET)"
                else
                    @error exception=(e, stacktrace(catch_backtrace()))
                end
            finally
                if isopen(socket)
                    write(socket, response)
                    BufferedStreams.close(buffered_stream)
                    Sockets.close(socket)
                else
                    println("stream closed ...")
                end
            end
        end
    end

    return request
end

end
