import socket
from datetime import datetime, timezone
import sys
import hashlib
import logging
import os

def generate_md5_hash(input_string):
    md5_hash = hashlib.md5(input_string.encode()).hexdigest()
    return md5_hash

# Check for command-line arguments
if len(sys.argv) < 3:
    print("Usage: python udp-receiver.py <port> <logfile>")
    print("Example: python udp-receiver.py 2022 output.log")
    sys.exit(1)

# Parse command-line arguments
localIP = "0.0.0.0"
localPort = int(sys.argv[1])
bufferSize = 2048
logfile_path = sys.argv[2]

# Define custom formatter for UTC timestamps
class UTCFormatter(logging.Formatter):
    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, timezone.utc)
        return dt.strftime('%m-%d-%Y %H:%M:%S UTC')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Remove any existing handlers (to avoid duplicates)
for handler in logger.handlers[:]:
    logger.removeHandler(handler)

# Create handlers
try:
    # File handler for log file
    file_handler = logging.FileHandler(logfile_path)
    file_handler.setFormatter(UTCFormatter('%(asctime)s: %(message)s'))
    logger.addHandler(file_handler)
    
    # Console handler for stdout
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(UTCFormatter('%(asctime)s: %(message)s'))
    logger.addHandler(console_handler)
except Exception as e:
    print(f"Error setting up logging to {logfile_path}: {e}")
    sys.exit(1)

def log(message):
    logger.info(message)

log(f"Listening on local port {localPort}")

# datagram socket
UDPServerSocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)

# Bind to address and ip
UDPServerSocket.bind((localIP, localPort))

log(f"UDP server up and listening [pid={os.getpid()}]")
 

# Listen for incoming datagrams

lastknownsocket = None
lastSequenceNumber = 0
packetsExpected = 10000000
packetSequenceNumber = 0
totalMissedPackets = 0
totalPacketsInTest = 0

while(True):

    bytesAddressPair = UDPServerSocket.recvfrom(bufferSize)
    message = bytesAddressPair[0].decode()
    address = bytesAddressPair[1]

    if lastknownsocket == None or lastknownsocket != address:
        testParams = message.split("|")
        lastSequenceNumber = int(testParams[0])
        if lastSequenceNumber != 0:
            # Skip this as the client needs to be restarted (we don't know the expected number of packets)
            continue
        packetsExpected = int(testParams[1])
        lastknownsocket = address
        totalMissedPackets = 0
        totalPacketsInTest = 0

        log(f"New test session from {address}. Packets expected: {packetsExpected}")
        totalPacketsInTest+=1
    else:
        packetSequenceNumber = int(message.split("|")[0])
        packetMessageString = message.split("|")[2]
        packetMessageHash = message.split("|")[1]
        calcMessageHash = generate_md5_hash(packetMessageString)        
        totalPacketsInTest+=1
        if packetMessageHash != calcMessageHash:
            log(f"Incorrect message hash in packet seqence number {packetSequenceNumber}")
            # continue to force an error as the hash is incorrect.
            continue
        if packetSequenceNumber == lastSequenceNumber + 1:
            lastSequenceNumber = packetSequenceNumber
        elif packetSequenceNumber == lastSequenceNumber + 2:
            totalMissedPackets = totalMissedPackets + 1 
            lastSequenceNumber = packetSequenceNumber
            log(f"One missed packet. Sequence number: {packetSequenceNumber}")
            log(f"Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")            
        elif packetSequenceNumber > lastSequenceNumber + 2:
            totalMissedPackets = totalMissedPackets + (packetSequenceNumber - lastSequenceNumber)
            lastSequenceNumber = packetSequenceNumber
            log(f"More than one missed packet. Sequence number: {packetSequenceNumber}")
            log(f"Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
        elif packetSequenceNumber < lastSequenceNumber:            
            totalMissedPackets = totalMissedPackets - 1 
            log(f"Out of order sequence number detected: {packetSequenceNumber}")
            log(f"Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
        if (packetsExpected == packetSequenceNumber):
            log(f"Test completed. Total Missed Packets = {totalMissedPackets}")
            log(f"Failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
            
        # Send a response
        bytesToSend = str.encode("0")
        UDPServerSocket.sendto(bytesToSend, address)

