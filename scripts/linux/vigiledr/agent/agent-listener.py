import socket

def getConfig():
    f = open('/etc/vigil/agent.conf', 'r')
    lines = f.readlines()
    f.close()
    for line in lines:
        if not line.startswith("#") or line.strip() == "":
            lineSplit = line.split("=")
            if lineSplit[0] == "manager_ip":
                global managerIP; managerIP = lineSplit[1].strip()
            elif lineSplit[0] == "management_port":
                global managementPort; managementPort = int(lineSplit[1].strip())
def main():
    getConfig()  # assumes this sets managementPort and managerIP

    # TCP socket
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", managementPort))
    s.listen(5)

    print("Vigil agent listener started on port:", managementPort)

    while True:
        conn, addr = s.accept()          # addr = (ip, port)
        client_ip = addr[0]

        # Only accept connections from managerIP
        if client_ip != managerIP:
            conn.close()
            continue

        try:
            data = conn.recv(1024)
            if not data:
                conn.close()
                continue

            command = data.decode("utf-8", errors="ignore").strip()

            if command == "check":
                conn.sendall("check".encode("utf-8"))
            elif command == "status":
                # Pending status implementation
                pass

        finally:
            conn.close()
main()