require 'socket'

class TCPServer
    def bound_addr; Socket::getnameinfo(getsockname)[0] end
    def port; Socket::getnameinfo(getsockname)[1].to_i end
end

