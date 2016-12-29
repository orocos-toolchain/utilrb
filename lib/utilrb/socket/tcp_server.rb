require 'socket'

class TCPServer
    def bound_addr; Socket.unpack_sockaddr_in(getsockname)[1] end
    def port; Socket.unpack_sockaddr_in(getsockname)[0] end
end

