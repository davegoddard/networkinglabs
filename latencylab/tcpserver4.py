import socketserver
import threading
import socket
import argparse

debug = False

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True

class ClientHandler(socketserver.StreamRequestHandler):
    def handle(self):
        client = f'{self.client_address[0]}:{self.client_address[1]} on {threading.current_thread().name}'
        if client.startswith("168.63.129.16") and debug:
            print("Dectected SLB Probe")
        elif debug:
            print(f'Connected: {client}')
        while True:
            data = self.rfile.readline()
            if not data:
                break
            if debug:
                print(f'Data: {client} wrote: {data.decode().strip()}')
            self.wfile.write(data)
        if client.startswith("168.63.129.16") == False and debug:
            print(f'Closed: {client}')

parser = argparse.ArgumentParser(description='Simple TCP server')
parser.add_argument('-ServerPort', type=int, default=9201, help="The port you want to listen on. By default, it is port 9201. Make sure this port is allowed via the local firewall.")
parser.add_argument('-Debug', type=bool, default=False, help="Show debug messages.")
args = parser.parse_args()

debug = args.Debug

with ThreadedTCPServer(('', args.ServerPort), ClientHandler) as server:
    print(f'The server is running...')
    server.serve_forever()