import socket
import mysql.connector
from datetime import datetime, timedelta
import threading

def getConfig():
    f = open('/etc/vigil/server.conf', 'r')
    lines = f.readlines()
    f.close()
    for line in lines:
        if not line.startswith("#") or line.strip() == "":
            lineSplit = line.split("=")
            if lineSplit[0] == "manager_port":
                global managerPort; managerPort = int(lineSplit[1].strip())
            if lineSplit[0] == "sql_user":
                global sqlUser; sqlUser = lineSplit[1].strip()
            if lineSplit[0] == "event_port":
                global eventPort; eventPort = int(lineSplit[1].strip())

def triggerAlert(alert):
    f = open("/var/log/vigil.log", "a")
    f.write('[' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + '] - ' + alert + "\n")
    f.close()
    threading.Thread(target=sendAlert, args=(alert, "127.0.0.1", eventPort), daemon=True).start()

def sendAlert(alert, managerIP, eventPort):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((managerIP, int(eventPort)))
        sock.sendall(alert.encode())
        sock.close()
    except:
        pass

def updateAgentList():
    conn = mysql.connector.connect(user=sqlUser, password="", host="localhost", database="Vigil_DB")
    cursor = conn.cursor()

    cursor.execute("SELECT ip FROM Agents;")

    ips = [row[0] for row in cursor.fetchall()]

    cursor.close()
    conn.close()
    return ips
    
def refreshHeardFromTime(agent):
    conn = mysql.connector.connect(user=sqlUser, password="", host="localhost", database="Vigil_DB")
    cursor = conn.cursor()

    sql = """
    INSERT INTO Agents (ip, last_heard_time)
    VALUES (%s, NOW())
    ON DUPLICATE KEY UPDATE last_heard_time = NOW()
    """
    cursor.execute(sql, (agent,))
    conn.commit()

    cursor.close()
    conn.close()

def agentTimedOut(ip_address: str) -> bool:
    conn = mysql.connector.connect(user=sqlUser, password="", host="localhost", database="Vigil_DB")
    cursor = conn.cursor()

    cursor.execute(
        "SELECT last_heard_time FROM Agents WHERE ip = %s;",
        (ip_address,)
    )
    result = cursor.fetchone()

    cursor.close()
    conn.close()

    if not result:
        return False  # or raise an error

    last_heard = result[0]  # This will already be a datetime object in MySQL connector

    # Compare times
    now = datetime.utcnow()
    return (now - last_heard) > timedelta(hours=1)

def run():
    getConfig()
    while True:
        agents = updateAgentList()

        for agent in agents:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(5)

            try:
                # TCP connect
                s.connect((agent, managerPort))

                # Send TCP message
                s.sendall("check".encode("utf-8"))

                # Receive response
                data = s.recv(1024)
                response = data.decode("utf-8", errors="ignore").strip()

                if response == "check":
                    refreshHeardFromTime(agent)
                else:
                    with open("/var/log/vigil_server.log", "a") as f:
                        f.write(
                            f"[{datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S')}] "
                            f"Unexpected response from agent {agent}: {response}\n"
                        )

                s.close()

            except (socket.timeout, ConnectionRefusedError, OSError):
                with open("/var/log/vigil_server.log", "a") as f:
                    f.write(
                        f"[{datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S')}] "
                        f"No response from agent {agent}\n"
                    )
                s.close()

            # If an agent hasn't checked in for over an hour
            if agentTimedOut(agent):
                triggerAlert("More than 1 hour has passed since last heard from agent: " + agent)

        threading.Event().wait(300)

run()