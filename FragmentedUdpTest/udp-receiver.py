import socket
from datetime import datetime,timezone
import datetime
import sys
import hashlib

localIP = "0.0.0.0"
localPort = 2022
bufferSize = 2048

if (len(sys.argv[1]) > 0):
    print(f"Listening on local port {sys.argv[1]}")
    localPort = int(sys.argv[1])
 
def generate_md5_hash(input_string):
    md5_hash = hashlib.md5(input_string.encode()).hexdigest()
    return md5_hash

# datagram socket
UDPServerSocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)

# Bind to address and ip
UDPServerSocket.bind((localIP, localPort))

print("UDP server up and listening")
 

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

        print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: New test session from {address}. Packets expected: {packetsExpected}")
        totalPacketsInTest+=1
    else:
        packetSequenceNumber = int(message.split("|")[0])
        packetMessageString = message.split("|")[2]
        packetMessageHash = message.split("|")[1]
        calcMessageHash = generate_md5_hash(packetMessageString)        
        totalPacketsInTest+=1
        if packetMessageHash != calcMessageHash:
            print(f"Incorrect message hash in packet seqence number {packetSequenceNumber}")
            # continue to force an error as the hash is incorrect.
            continue
        if packetSequenceNumber == lastSequenceNumber + 1:
            lastSequenceNumber = packetSequenceNumber
        elif packetSequenceNumber == lastSequenceNumber + 2:
            totalMissedPackets = totalMissedPackets + 1 
            lastSequenceNumber = packetSequenceNumber
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: One missed packet. Sequence number: {packetSequenceNumber}")
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")            
        elif packetSequenceNumber > lastSequenceNumber + 2:
            totalMissedPackets = totalMissedPackets + (packetSequenceNumber - lastSequenceNumber)
            lastSequenceNumber = packetSequenceNumber
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: More than one missed packet. Sequence number: {packetSequenceNumber}")
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
        elif packetSequenceNumber < lastSequenceNumber:            
            totalMissedPackets = totalMissedPackets - 1 
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Out of order sequence number detected: {packetSequenceNumber}")
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Current failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
        if (packetsExpected == packetSequenceNumber):
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Test completed. Total Missed Packets = {totalMissedPackets}")
            print(f"{datetime.datetime.now(timezone.utc).strftime('%m-%d-%Y %H:%M:%S')} UTC: Failure rate: {(totalMissedPackets/totalPacketsInTest)*100}")
            
        # Send a response
        bytesToSend = str.encode("0")
        UDPServerSocket.sendto(bytesToSend, address)

