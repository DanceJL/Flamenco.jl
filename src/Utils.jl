module Utils

"""
    has_header(headers::Dict{String, String}, key::String, value::String) :: Bool

Check whether corresponding (key, value) pair exists in Header
"""
function has_header(headers::Dict{String, String}, key::String, value::String) :: Bool
    return headers[key] == value
end

end
