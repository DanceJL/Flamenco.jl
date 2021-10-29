# Flamenco

| **Build Status**                                       |
|:------------------------------------------------------:|
| [![Build Status](https://travis-ci.com/DanceJL/Flamenco.jl.svg?branch=master)](https://travis-ci.com/DanceJL/Flamenco.jl)  [![codecov](https://codecov.io/gh/DanceJL/Flamenco.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/DanceJL/Flamenco.jl)|

## 1 - Introduction

Simple and fast HTTP parser for CRUD API backend Julia web frameworks.

Takes advantage of Julia multi-threading via [ThreadPools](https://github.com/tro3/ThreadPools.jl) and parses requests as buffer via [BufferedStreams](https://github.com/BioJulia/BufferedStreams.jl/).

Architecture inspired from [PicoHTTPParser](https://github.com/h2o/picohttpparser).

## 2 - Setup

Simply wrap your routing function inside `start_server`:

```julia
Flamenco.start_server("127.0.0.1", 8000) do request::Flamenco.Server.Request
    routes(; request_headers=request.headers, request_method=request.method, request_path=request.target, request_payload=request.body)
end
```

Your routing function must accept the 4 arguments:
- request.headers ::Dict{String, String}
- request.method ::String
- request.target ::String
- request.body ::String

`Content-Type` Header must be set inside your routing function as well. If `Content-Length` and `Date` Headers are not set, Flamenco will automatically set these in the HTTP response.

If you would prefer this routing logic to be automatically taken care of, see [DanceJL](https://github.com/DanceJL/Dance.jl) as an example..

# 3 - Supported HTTP Standards

Currently only HTTP 1.1 is supported.

Also the incoming request must be one of: DELETE, GET, OPTIONS, POST or PUT.
