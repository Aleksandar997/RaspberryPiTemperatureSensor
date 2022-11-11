from src import controller
from src import service
from threading import Thread

def create_app():
    server_thread = Thread(target=service.run)
    server_thread.daemon = True
    server_thread.start()
    controller.init()


