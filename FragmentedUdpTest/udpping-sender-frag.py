from asyncio import sleep
import socket
import time
import sys
import random
import string
import hashlib
from datetime import datetime,timezone

timeBetweenPings = 1  # This must be at least 0.001 so that the receiver can keep up
padmessage = True  # Set this to true if you want to force packet size

if len(sys.argv) != 4:
    print(f"Please specify server IP and port on the command line. So {sys.argv[0]} <Server IP> <Port> <filename>")
    exit()

serverAddressPort = (sys.argv[1], int(sys.argv[2]))
bufferSize = 2048
totalMessages = 10000000

try:
    logfile = open(sys.argv[3],"a")
except:
    print(f"Failed to open log file")
    exit()

def generate_random_string(length):
    characters = string.ascii_lowercase + string.digits
    random_string = ''.join(random.choice(characters) for i in range(length))
    return random_string

def generate_md5_hash(input_string):
    md5_hash = hashlib.md5(input_string.encode()).hexdigest()
    return md5_hash

# Create a UDP socket
udpSocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
udpSocket.settimeout(1) # timeout ping after one second

# Initialize flow
message = f"0|{totalMessages}"
bytesToSend = str.encode(message)
udpSocket.sendto(bytesToSend, serverAddressPort)

totalLatency = 0
totalFailures = 0
totalSuccess = 0

i = 1
while (i <= totalMessages):

    randomstr = generate_random_string(1600)
    hashstr = generate_md5_hash(randomstr) 
    message = f"{i}|{hashstr}|{randomstr}"
    # Send to server using created UDP socket
    if padmessage == True:
        message = message.ljust(1600,"0")
    bytesToSend = str.encode(message)

    sendTime = time.time()
    udpSocket.sendto(bytesToSend, serverAddressPort)

    try:
        data, server = udpSocket.recvfrom(10240)
        recvTime = time.time()
        elapsed = recvTime - sendTime
        totalLatency+=elapsed
        totalSuccess+=1

        if i != 0:
            logfile.write(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')},{sys.argv[1]},success,{i},{(elapsed*1000):.2f}\n") # Don't log connectionsetup
            print(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}: Success - {(elapsed*1000):.2f} ms")

    except socket.timeout:
        logfile.write(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')},{sys.argv[1]},timeout,{i},\n")
        print(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}: TIMEOUT - seq {i}")
        totalFailures+=1

    i = i + 1

    time.sleep(timeBetweenPings)

    if i % 100 == 0:
        if totalSuccess > 0:
            print(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}: Current total successes: {totalSuccess} Total Failures: {totalFailures} Average Latency: {(totalLatency/totalSuccess)*1000:.2f}")
        else:
            print(f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')}: No successes detected")


print(f"Sent messages!")