from logging import *

logger: Logger

def log_debug(message):
    logger.debug(message)

def log_info(message):
    logger.info(message)

def log_warning(message):
    logger.warning(message)

def log_exception(message):
    logger.exception(message)

def log_critical(message):
    logger.critical(message)

basicConfig(filename="exception.log", 
                format='%(asctime)s %(message)s', 
                filemode='w') 

logger = getLogger()
logger.setLevel(DEBUG)

