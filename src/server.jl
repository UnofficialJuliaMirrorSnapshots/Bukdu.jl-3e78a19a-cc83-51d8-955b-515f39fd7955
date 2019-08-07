# module Bukdu

using .Deps.HTTP
using .HTTP.Sockets

const env = Dict{Symbol, Any}(
    :server => nothing,
)

function routing_handle(request::HTTP.Request)
    route = Routing.handle(request)
    result = request_handler(route, request)
    result.resp
end

"""
    Bukdu.start(port::Integer; host::Union{String,Sockets.IPAddr}="localhost", kwargs...)

start the Bukdu server.
"""
function start(port::Integer; host::Union{String,Sockets.IPAddr}="localhost", kwargs...)
    ipaddr = host isa Sockets.IPAddr ? host : Sockets.getaddrinfo(host)
    inetaddr = Sockets.InetAddr(ipaddr, port)
    server = Sockets.listen(inetaddr)
    env[:server] = server
    task = @async HTTP.serve(ipaddr, port; server=server, verbose=false, kwargs...) do req
        if env[:server] === nothing
            req.response.status = 503
            Plug.Loggers.print_message("503 Error", req)
            throw(ErrorException("503"))
            req.response
        else
            routing_handle(req)
        end
    end
    print_listening_on(inetaddr)
    task
end

"""
    Bukdu.stop()

stop the Bukdu server.
"""
function stop()
    server = env[:server]
    if server !== nothing
        close(server)
        env[:server] = nothing
        Plug.Loggers.print_message("Stopped.")
    end
    nothing
end

struct StyledInetAddr{T<:Sockets.IPAddr}
    host::T
    port::UInt16
    StyledInetAddr(addr::Sockets.InetAddr) = new{typeof(addr.host)}(addr.host, addr.port)
end

function Base.show(io::IO, saddr::StyledInetAddr)
    printstyled(io, string(saddr.host, ':', saddr.port), color=:green)
end

function print_listening_on(addr::Sockets.InetAddr)
    Plug.Loggers.print_message("Bukdu Listening on ", StyledInetAddr(addr))
end

# module Bukdu
