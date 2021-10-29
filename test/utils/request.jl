import Dates
import HTTP
import JSON


function compare_http_date_header(header_value::String, timestamp_request_completed::Dates.DateTime) :: Nothing
    header_value_timestamp::Dates.DateTime = Dates.DateTime(split(header_value, " UTC")[1], "e, d u Y H:M:S")
    @test header_value_timestamp <= timestamp_request_completed
    nothing
end


function compare_http_header(headers::Array, key::String, value::String) :: Nothing
    @test header_get_value(headers::Array, key::String)==value
    nothing
end


function header_get_value(headers::Array, key::String) :: String
    for item in headers
        if item[1]==key
            return item[2]
        end
    end
end


function parse_and_test_request(r::HTTP.Messages.Response, status::Int64, headers::Vector{Pair{String,String}}, content_length::Int64, is_json::Bool, is_get::Bool, body::Union{Dict, String}="")
    timestamp_request_completed::Dates.DateTime = Dates.now(Dates.UTC)

    @test r.status==status

    for (key, value) in headers
        compare_http_header(r.headers, key, value)
    end
    compare_http_date_header(header_get_value(r.headers, "Date"), timestamp_request_completed)
    # TODO: fix Windows HTML file longer due to line final char
    if !Sys.iswindows()
        compare_http_header(r.headers, "Content-Length", string(content_length))
    end

    if is_json
        header_get_value(r.headers, "Content-Type") == "application/json"
        @test JSON.json(body) == String(r.body)
    elseif is_get
        header_get_value(r.headers, "Content-Type") == "text/html; charset=UTF-8"
        @test occursin("Content ...", String(r.body))
    else
        length(r.body) == 0
    end

    nothing
end
