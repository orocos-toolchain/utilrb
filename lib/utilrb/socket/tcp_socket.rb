
class TCPSocket
    def peer_info; Socket::getnameinfo(getpeername) end
    def peer_addr; Socket::getnameinfo(getpeername)[0] end
    def peer_port; Socket::getnameinfo(getpeername)[1] end
end

