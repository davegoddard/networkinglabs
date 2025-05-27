#!/usr/bin/env python3

# Import the socket module
import socket
import time
import argparse
import threading
import sys
from ipaddress import ip_address, IPv4Address
from datetime import datetime, timezone

# Function to log messages with timestamp
def log(message):
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    formatted_message = f"{timestamp}: {message}"
    
    if log_file:
        try:
            with open(log_file, 'a') as f:
                f.write(f"{formatted_message}\n")
        except Exception as e:
            print(f"Error writing to log file: {e}")
    
    print(formatted_message)

parser = argparse.ArgumentParser(description='Simple TCP client')
parser.add_argument('-ServerIP', type=str, help='The destination server IP')
parser.add_argument('-ServerPort', type=int)
parser.add_argument('-TotalMessagesToSend', type=int, default="100000", help='The number of messages to send per socket')
parser.add_argument('-MessagesPerSocket', type=int, default="1", help='The number of messages to send per socket')
parser.add_argument('-SecondsBetweenMessages', type=float, default="0", help='The number of seconds between messages. Default 0.')
parser.add_argument('-TotalWorkers', type=int, default="1", help='The number of workers sending the total number of messages. Default 1.')
parser.add_argument('-Message',type=str, default="hello", help='The message to send to the server')
parser.add_argument('-Debug', type=bool, default=False, help='Print debug messages')
parser.add_argument('-LogFile', type=str, help='Path to log file (optional)')

args = parser.parse_args()

# Set up the log file path if provided
log_file = args.LogFile if args.LogFile else None

if args.ServerIP is None:
    log("Did not specify server IP with -ServerIP. Quitting.")
    exit()
else:
    try:
        if type(ip_address(args.ServerIP)) is IPv4Address:
            sockettype = socket.AF_INET
        else:
            sockettype = socket.AF_INET6
    except ValueError:
        log("ServerIP is not recognized as a proper IPv4 or IPv6 address. Quitting.")
        exit()

serverport = 9201
if args.ServerPort is None:
    log(f"Did not specify server port with -ServerPort. Setting to {serverport}.")
else:
    serverport = args.ServerPort

# Define the destination address and port
dst = (args.ServerIP, serverport)
message = f"{args.Message}\n"
messagesSent = 0

startTime = time.perf_counter()

class MessageCounter():
    def __init__(self):
        self.lock = threading.Lock()
        self.counter = 0

    def increment(self):
        with self.lock:
            self.counter += 1
            return  self.counter

def ClientWorker(counter):

    messageNumber = counter.increment()

    while messageNumber <= args.TotalMessagesToSend:
        with socket.socket(sockettype, socket.SOCK_STREAM) as s:

            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

            messagesSentWithCurrentSocket = 0

            if args.Debug:
                log("Connecting to new socket")

            try:
                s.connect(dst)
            except Exception as e:
                log(f"Failed to connect to server {dst}. Verify that the server process is running and that the connection is allowed throught any NSG(s) and guest OS firewalls.")
                time.sleep(0.01)
                continue

            while (messagesSentWithCurrentSocket < args.MessagesPerSocket and messageNumber <= args.TotalMessagesToSend):
                messagesSentWithCurrentSocket+=1
                if args.Debug:
                    log("Sending Message")

                instanceMessage = f"{messageNumber}: {message}"
                s.sendall(instanceMessage.encode('utf-8'))

                # Receive the response from the destination
                resp = s.recv(2000)

                if args.Debug:
                    # Decode the response as a string
                    resp_str = resp.decode('utf-8').strip()
                    # Print the response
                    log(f"Received: {resp_str}")

                # Sleep (potentially)
                time.sleep(args.SecondsBetweenMessages)

                # Get the next message:
                messageNumber = counter.increment()

            s.close()

log("Starting test")
ctr = MessageCounter()
clientThreads = [threading.Thread(target=ClientWorker, args=(ctr,)) for _ in range(args.TotalWorkers)]
for thread in clientThreads:
    thread.start()
    time.sleep(0.01)
for thread in clientThreads:
    thread.join()

# Send summary
log("Test complete")
endTime = time.perf_counter()
elapsedTime = round(endTime - startTime, 2)
if args.TotalMessagesToSend > 0 and elapsedTime > 0:
    messagesPerSec = round((args.TotalMessagesToSend / elapsedTime), 2)
log(f"Sent {args.TotalMessagesToSend} messages in {elapsedTime} seconds ({messagesPerSec} messages per sec).")
