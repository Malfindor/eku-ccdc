import os
import subprocess
import datetime
lastRefresh = ""
filters = []
def main():
    while True:
        os.system("clear")
        readCont = getFileCont("/var/Arbiter/read.log")
        if(len(readCont) != 0 && readCont != "\n"):
            os.system('echo "' + readCont + '" >> /var/Arbiter/active.log')
            os.system("mv /var/Arbiter/buffer.log /var/Arbiter/read.log")
            os.system("touch /var/Arbiter/buffer.log")
            os.system('echo "' + readCont + '" + >> /var/log/masterArbiter.log')
        lastRefresh = datetime.datetime.today()
        logs = getFileCont("/var/Arbiter/active.log")
        logList = logs.split('\n')
        print("Last refresh: " + str(lastRefresh))
        x = 0
        for log in logList:
            print(str(x+1) + ": " + log)
            x = x + 1
    
        x = True
        while(x):
            option = input("Enter command: ").lower()
            if(len(option) != 0):
                x = False
        if(option == "refresh" or option == "re"):
            pass
        elif(option == "filter"):
            x = True
            newFilter = input("Enter filter to add: ").lower()
            firstSplit = newFilter.split(" ")
            if(firstSplit[0] == "machine"):
                pass
            elif(firstSplit[0] == "message" or firstSplit[0] == "log"):
                pass
            else:
                pass
        elif((option.split(" "))[0] == "ack"):
            if(len(option.split(" ")) == 1):
                print("Missing log number to acknowledge.")
            else:
                acked = (option.split(" "))[1]
                if(acked > len(logList)):
                    print("Invalid log identifier.")
                else:
                    del(logList[acked-1])
                    newLogList = "\n".join(logList)
                    os.system('echo "' + newLogList + '" > /var/Arbiter/active.log')
        else:
            printHelp()
    
    
main()
def getFileCont(file):
    command = "cat " + file
    try:
        fileCont = subprocess.check_output(command, shell=True)
        fileDecode = fileCont.decode("utf-8")
        return fileDecode
    except subprocess.CalledProcessError as e:
        return ""
def printFilters():
    message = ""
    for filter in filters:
        message = message + "[" + filter + "], "
    print(message[:len(message)-2])
def printHelp():
    print("""
Arbiter SIM Information:

    Commands:
        
        Refresh - Refreshes the current log list
        Filter - Adds a filter to the current search
        Ack # - Acknowledges a given alert and removes it from the list
    
    Filter Format:
        
        Legend:
            {...} - Interchangable, same effect either way
            (...) - One or the Other
            [...] - Variable Input
            
        Filter by machine: 'machine (is/is not) [ip/machine_name(fedora/ecom/centos/debian/etc)]'
        Filter by content: '{log/message} (does/does not) contain [string]'

""")
def printFormat():
    print("""
Filter Format:
        
    Legend:
        {...} - Interchangable, same effect either way
        (...) - One or the Other
        [...] - Variable Input
            
    Filter by machine: 'machine (is/is not) [ip/machine_name(fedora/ecom/centos/debian/etc)]'
    Filter by content: '{log/message} (does/does not) contain [string]'
""")