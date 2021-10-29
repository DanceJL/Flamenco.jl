include("utils/main.jl")


server_start()

make_and_test_request_delete(["a" => "b"])
make_and_test_request_get(["a" => "b"])
make_and_test_request_options(["a" => "b"])
make_and_test_request_put(["a" => "b"], Dict("a" => 1), 7)
make_and_test_request_post(["a" => "b"], Dict("b" => 2), 7)

server_close()
