module Writer

import Dates

include("./status_codes.jl")


"""
    write(status_code::Int16, headers::Dict{String, String}; body::String="") :: String

Return HTTP response string
- Status line
- Headers
- Empty line
- Body (optional)
"""
function write(status_code::Int16, headers::Dict{String, String}; body::String="") :: String
    status_code_string::String = string(status_code) * " " * status_codes[status_code]
    response::String = "HTTP/1.1 " * status_code_string * "\n"

    if !haskey(headers, "Date")
        timestamp::Dates.DateTime = Dates.now(Dates.UTC)
        dayname::String = Dates.dayabbr(timestamp)
        day::Int64 = Dates.day(timestamp)
        monthname::String = Dates.monthabbr(timestamp)
        year::Int64 = Dates.year(timestamp)
        hour::Int64 = Dates.hour(timestamp)
        minute::Int64 = Dates.minute(timestamp)
        second::Int64 = Dates.second(timestamp)
        date_string::String = "$dayname, $day $monthname $year $hour:$minute:$second UTC"
        response *= "Date: " * date_string * "\n"
    end

    if !haskey(headers, "Content-Length")
        response *= "Content-Length: " * string(length(body)) * "\n"
    end

    for (key, val) in headers
        response *= "$key: $val\n"
    end

    # TODO: Only if Http 1.1
    # if Utils.has_header(headers, "Connection", "close")
    response *= "Connection: Closed"

    if body != ""
        response *= "\n\n" * body
    end

    return response
end

end
