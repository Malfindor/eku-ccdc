import mysql.connector
from datetime import datetime
import os
from time import sleep

def getAlerts():
    conn = mysql.connector.connect(user=sqlUser, password="", host="localhost", database="Vigil_DB")
    cursor = conn.cursor(dictionary=True)

    query = """SELECT
    a.id,
    a.ingest_time,
    a.alert_time,
    ag.ip AS agent_ip,
    a.message,
    a.ack
    FROM Alerts a
    JOIN Agents ag ON ag.id = a.agent_id
    WHERE a.ack = FALSE
    ORDER BY a.alert_time DESC;
    """
    cursor.execute(query)
    results = cursor.fetchall()
    cursor.close()
    conn.close()
    return results

def clearTerminal():
    os.system('cls' if os.name == 'nt' else 'clear')

def acknowledgeAlert(alert_id):
    conn = mysql.connector.connect(
        user=sqlUser,
        password="",
        host="localhost",
        database="Vigi"
    )
    cursor = conn.cursor()

    query = """
    UPDATE Alerts
    SET ack = TRUE
    WHERE id = %s
    """

    cursor.execute(query, (alert_id,))
    conn.commit()

    rows_updated = cursor.rowcount

    cursor.close()
    conn.close()

    return rows_updated == 1

def parseConf():
    f = open('/etc/vigil/server.conf', 'r')
    confContents = f.readlines()
    f.close()
    for line in confContents:
        if not len(line) == 0:
            if not line[0] == '#':
                if line.split('=')[0] == 'sql_user':
                    global sqlUser; sqlUser = line.split('=')[1]

def run():
    config = parseConf()
    cont = True
    invalid = False
    while cont:
        clearTerminal()
        print("Vigil Event Viewer")
        alerts = getAlerts()
        lastRefresh = datetime.now()
        print("Last refresh time: {}".format(lastRefresh.strftime("%Y-%m-%d %H:%M:%S")))
        print("Unacknowledged alerts: {}".format(len(alerts)))
        print("-" * 50)
        for alert in alerts:
            print("[{}] - [{}] - {} - {}".format(alert['id'], alert['alert_time'].strftime("%Y-%m-%d %H:%M:%S"), alert['agent_ip'], alert['message']))
        print("-" * 50)
        if invalid:
            print("Invalid input. Please try again.")
            invalid = False
        userInput = input("Enter alert ID to acknowledge, or 'r' to refresh, or 'q' to quit: ")
        if userInput.lower() == 'q':
            cont = False
        elif userInput.lower() == 'r':
            continue
        else:
            try:
                alertID = int(userInput)
                if acknowledgeAlert(alertID):
                    print("Alert {} acknowledged.".format(alertID))
                    sleep(1)
                else:
                    print("Alert ID {} not found.".format(alertID))
                    sleep(1)
            except ValueError:
                invalid = True
