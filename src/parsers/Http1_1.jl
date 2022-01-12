module ParserHttp1_1

import BufferedStreams
import Dates

include("../errors.jl")


ASCII_CODE_COLON = 58
ASCII_CODE_CR = 13  # Carriage Return
ASCII_CODE_HT = 9  # Horizontal tab
ASCII_CODE_LF = 10  # Line Feed
ASCII_CODE_SPACE = 32
ASCII_PRINTABLE_RANGE_LOWER = 32
ASCII_PRINTABLE_RANGE_UPPER = 127
FAILED = false  # Whether parsing failed


#=
    Private functions
=#

"""
    _check_next_char_as_expected(stream::BufferedStreams.BufferedInputStream, ch::Int64) :: Bool

Check if next char in stream matches expectation
"""
function _check_next_char_as_expected(stream::BufferedStreams.BufferedInputStream, ch::Int64) :: Bool
    is_expected_stream_next_char::Bool = false

    if BufferedStreams.read(stream, 1)[1] == ch
        is_expected_stream_next_char = true
    else
        global FAILED
        FAILED = true
    end

    return is_expected_stream_next_char
end


"""
    _found_crlf(stream::BufferedStreams.BufferedInputStream) :: Bool

Find CRLF (line termination)
"""
function _found_crlf(stream::BufferedStreams.BufferedInputStream) :: Bool
    ch::UInt8 = BufferedStreams.read(stream, 1)[1]
    found_crlf::Bool = false

    while (!found_crlf)
        if ch == ASCII_CODE_CR
            if _check_next_char_as_expected(stream, ASCII_CODE_LF)
                found_crlf = true
            end
        else
            global FAILED
            FAILED = true
        end
    end

    return found_crlf
end


"""
    _is_eof(stream::BufferedStreams.BufferedInputStream) :: Bool

Check if parsing reached end of stream
"""
function _is_eof(stream::BufferedStreams.BufferedInputStream) :: Bool
    is_eof::Bool = false

    if stream.available == 0
        global FAILED
        FAILED = true
    end

    return is_eof
end


"""
    _is_http_1_1(stream::BufferedStreams.BufferedInputStream) :: Bool

Ensure is HTTP 1.1
"""
function _is_http_1_1(stream::BufferedStreams.BufferedInputStream) :: Bool
    final_check::Bool = false

    if (stream.position + 8 > stream.available)
        global FAILED
        FAILED =true
    else
        check::Bool = true
        while (check)
            check = _check_next_char_as_expected(stream, 72)  # H
            check = _check_next_char_as_expected(stream, 84)  # T
            check = _check_next_char_as_expected(stream, 84)  # T
            check = _check_next_char_as_expected(stream, 80)  # P
            check = _check_next_char_as_expected(stream, 47)  # /
            check = _check_next_char_as_expected(stream, 49)  # 1
            check = _check_next_char_as_expected(stream, 46)  # .
            check = _check_next_char_as_expected(stream, 49)  # 1
            final_check = true
            check = false
        end
    end

    return final_check
end


"""
    _is_printable_ascii(ch::UInt8) :: Bool

Check if char is printable ASCII value
"""
_is_printable_ascii(ch::UInt8) :: Bool = ASCII_PRINTABLE_RANGE_LOWER <= ch <= ASCII_PRINTABLE_RANGE_UPPER


"""
    _parse_body(stream::BufferedStreams.BufferedInputStream, method::String) :: String

Return Body as String, for PUT & POST requests
"""
function _parse_body(stream::BufferedStreams.BufferedInputStream, method::String) :: String
    buffer::String = ""

    function _read_body()
        buffer = String(UInt8.(BufferedStreams.read(stream)))
    end

    if (method == "PUT" || method == "POST")
        # Skip first empty line (some clients add CRLF before POST content)
        if (BufferedStreams.peek(stream) == ASCII_CODE_CR)
            BufferedStreams.read(stream, 1)
            if _check_next_char_as_expected(stream, ASCII_CODE_LF)
                _read_body()
            else
                global FAILED
                FAILED = -2
            end
        else
            _read_body()
        end
    end

    return buffer
end


"""
    _parse_headers(stream::BufferedStreams.BufferedInputStream) :: Dict{String, String}

Return Header as Dict
As counter-measure againt Slowloris attack, if parsing takes longer than 4 seconds => return 408 status
"""
function _parse_headers(stream::BufferedStreams.BufferedInputStream) :: Dict{String, String}
    finished::Bool = false
    headers::Dict{String, String} = Dict()
    timeout::Bool = true

    function _check_end_of_header()
        if (BufferedStreams.read(stream, 1)[1] == ASCII_CODE_CR)
            if (BufferedStreams.read(stream, 1)[1] == ASCII_CODE_LF)
                if (BufferedStreams.read(stream, 1)[1] == ASCII_CODE_CR)
                    if (BufferedStreams.read(stream, 1)[1] == ASCII_CODE_LF)
                        finished = true
                    else
                        global FAILED
                        FAILED = true
                    end
                else
                    BufferedStreams.seek(stream, stream.position-2)
                end
            else
                global FAILED
                FAILED = true
            end
        else
            global FAILED
            FAILED = true
        end
    end

    function _header_append(header_name::String, header_value::String)
        if (length(header_name)==0 || length(header_value)==0)
            global FAILED
            FAILED = true
        else
            headers[header_name] = header_value
        end
    end

    # Parse each header line
    # If longer than 4 seconds -> return 408 status
    start::Int64 = Int(floor(Dates.datetime2unix(Dates.now())))
    while( !finished && Int(floor(Dates.datetime2unix(Dates.now()))) - start < 4 )
        while (!_is_eof(stream) && !FAILED && !finished)
            fill_header_name::Bool = true
            header_name::String = ""
            header_value::String = ""
            next_ch::UInt8 = BufferedStreams.peek(stream)

            while (!FAILED && next_ch!=ASCII_CODE_CR && _is_printable_ascii(next_ch))
                # Parsing name part (LHS of colon), but do not discard SP before colon
                if (next_ch == ASCII_CODE_COLON)
                    BufferedStreams.read(stream, 1)
                    if (BufferedStreams.peek(stream)==ASCII_CODE_SPACE || BufferedStreams.peek(stream)==ASCII_CODE_HT)
                        fill_header_name = false
                        BufferedStreams.read(stream, 1)
                    else
                        BufferedStreams.seek(stream, stream.position-1)
                        if (BufferedStreams.peek(stream) in [33:1:57;] || BufferedStreams.peek(stream) in [59:1:126;])  # ! till 9, &lt; till ~
                            if fill_header_name
                                header_name *= String(UInt8.(BufferedStreams.read(stream, 1)))
                            else
                                header_value *= String(UInt8.(BufferedStreams.read(stream, 1)))
                            end
                        end
                    end
                elseif (next_ch==ASCII_CODE_SPACE || next_ch==ASCII_CODE_HT)
                    BufferedStreams.read(stream, 1)
                    if (BufferedStreams.peek(stream)==ASCII_CODE_COLON)
                        fill_header_name = false
                        BufferedStreams.read(stream, 1)
                    end
                elseif (next_ch in [33:1:57;] || next_ch in [59:1:126;])  # ! till 9, &lt; till ~
                    if fill_header_name
                        header_name *= String(UInt8.(BufferedStreams.read(stream, 1)))
                    else
                        header_value *= String(UInt8.(BufferedStreams.read(stream, 1)))
                    end
                else
                    global FAILED
                    FAILED = true
                end
                next_ch = BufferedStreams.peek(stream)
            end

            _check_end_of_header()
            _header_append(header_name, header_value)
        end
        timeout = false
    end

    if timeout
        throw(TimeoutError())
    end

    return headers
end


"""
    _parse_method(stream::BufferedStreams.BufferedInputStream) :: String

Return HTTP method as String, among [DELETE, GET, OPTIONS, POST, PUT]
"""
function _parse_method(stream::BufferedStreams.BufferedInputStream) :: String
    ch::UInt8 = BufferedStreams.read(stream, 1)[1]
    check::Bool = true
    method::String = ""

    while (check)
        if (ch == 68)  # D
            check = _check_next_char_as_expected(stream, 69)  # E
            check = _check_next_char_as_expected(stream, 76)  # L
            check = _check_next_char_as_expected(stream, 69)  # E
            check = _check_next_char_as_expected(stream, 84)  # T
            check = _check_next_char_as_expected(stream, 69)  # E
            method = "DELETE"
            check = false
        elseif (ch == 71)  # G
            check = _check_next_char_as_expected(stream, 69)  # E
            check = _check_next_char_as_expected(stream, 84)  # T
            method = "GET"
            check = false
        elseif (ch == 79)  # O
            check = _check_next_char_as_expected(stream, 80)  # P
            check = _check_next_char_as_expected(stream, 84)  # T
            check = _check_next_char_as_expected(stream, 73)  # I
            check = _check_next_char_as_expected(stream, 79)  # O
            check = _check_next_char_as_expected(stream, 78)  # N
            check = _check_next_char_as_expected(stream, 83)  # S
            method = "OPTIONS"
            check = false
        elseif (ch == 80)  # P
            ch = BufferedStreams.read(stream, 1)[1]
            if (ch == 79)  # O
                check = _check_next_char_as_expected(stream, 83)  # S
                check = _check_next_char_as_expected(stream, 84)  # T
                method = "POST"
                check = false
            elseif (ch == 85)  # U
                check = _check_next_char_as_expected(stream, 84)  # T
                method = "PUT"
                check = false
            else
                check = false
            end
        else
            check = false
        end
    end

    if method == ""
        global FAILED
        FAILED = true
    end

    return method
end


"""
    _parse_request_line(stream::BufferedStreams.BufferedInputStream) :: Tuple{String, String}

Return Method & Target from Request line
"""
function _parse_request_line(stream::BufferedStreams.BufferedInputStream) :: Tuple{String, String}
    method::String = ""
    target::String = ""

    while (!FAILED)
        method = _parse_method(stream)
        _check_next_char_as_expected(stream, ASCII_CODE_SPACE)

        target = _parse_target(stream)
        _check_next_char_as_expected(stream, ASCII_CODE_SPACE)

        if (length(method)==0 || length(target)==0)
            global FAILED
            FAILED = true
        end

        if !_is_http_1_1(stream)
            global FAILED
            FAILED = true
        end

        if !_found_crlf(stream)
            global FAILED
            FAILED = true
        end
        break
    end

    return method, target
end


"""
    _parse_target(stream::BufferedStreams.BufferedInputStream) :: String

Return Target as String
"""
function _parse_target(stream::BufferedStreams.BufferedInputStream) :: String
    ch::UInt8 = BufferedStreams.peek(stream)
    target::String = ""

    while (ch != ASCII_CODE_SPACE)
        target *= String(UInt8.(BufferedStreams.read(stream, 1)))
        ch = BufferedStreams.peek(stream)
    end

    return target
end


#=
    Public functions
=#

"""
    parse_request(stream::BufferedStreams.BufferedInputStream) :: Tuple {String, String, Dict{String, String}, String}

Parse HTTP request (Target, Method, Headers, Body)
Only parse Header once, as counter-measure againt Slowloris attack
"""
function parse_request(stream::BufferedStreams.BufferedInputStream) :: Tuple{String, String, Dict{String, String}, String}
    body::String = ""
    header_parsed::Bool = false
    headers::Dict{String, String} = Dict()
    method::String = ""
    target::String = ""

    global FAILED
    FAILED = false

    while (!FAILED)
        # Only parse Header once (counter-measure againt Slowloris attack)
        if stream.position > 1 && !header_parsed
            method, target = _parse_request_line(stream)
            headers = _parse_headers(stream)
            header_parsed = true
        else
            method, target = _parse_request_line(stream)
            headers = _parse_headers(stream)
        end

        body = _parse_body(stream, method)
        break
    end

    if FAILED
        throw(InternalError())
    end

    return target, method, headers, body
end

end
