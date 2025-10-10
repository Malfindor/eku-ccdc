#!/usr/env/python3
import socket
import threading
from datetime import datetime
import mysql.connnector

def parseConf():
    conf = ["127.0.0.1", 5678]
    f = open('/etc/vigil.conf', 'r')
    confContents = f.read()
    confContentsSplit = confContents.split('\n')
    for line in confContentsSplit:
        if not line[0] == '#':
            if line.split('=')[0] == 'bind_ip':
                conf[0] = line.split('=')[1][1:-1]
            elif line.split('=')[0] == 'bind_port':
                conf[1] = line.split('=')[1]
    return conf

def handleMessage(message, agent):
    if message == "checkin":
        refreshHeardFromTime(agent)
    else:
        saveToSQL(message, agent)
def saveToSQL(message, agent):
    messageSplit = message.split(' - ')
    if len(messageSplit) != 2:
        return
    
    raw_time = messageSplit[0].strip("[]")
    alertMessage = messageSplit[1].strip()

    try:
        alertTime = datetime.strptime(raw_time, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        print("Invalid datetime format:", raw_time)
        return

    conn = mysql.connector.connect(user="user", password="pass", host="localhost", database="Vigil_DB")
    cursor = conn.cursor()

    query = """
    INSERT INTO Alerts (agent_id, alert_time, message)
    SELECT id, %s, %s FROM Agents WHERE ip = %s
    """
    cursor.execute(query, (alertTime, alertMessage, agent))
    conn.commit()

    sql = """
    INSERT INTO Agents (ip, last_heard_time)
    VALUES (%s, NOW())
    ON DUPLICATE KEY UPDATE last_heard_time = NOW()
    """
    cursor.execute(sql, (agent,))
    conn.commit()

    cursor.close()
    conn.close()
def refreshHeardFromTime(agent):
    conn = mysql.connector.connect(user="user", password="pass", host="localhost", database="Vigil_DB")
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
def run():
    config = parseConf() # config returns as [{bindIP}, {bindPort}]
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((config[0], int(config[1])))
    sock.listen(5)
    print('Vigil listener started on ' + config[0] + ':' + str(config[1]) + '.')
    while True:
        conn, addr = sock.accept()
        agent = addr[0]
        data = conn.recv(4096)
        if data:
            message = data.decode(errors="ignore")
            threading.Thread(target=handleMessage, daemon=True).start() # Add variables 
        conn.close()
run()