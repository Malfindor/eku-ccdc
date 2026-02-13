import logging
import sys

#arguments:
#       1. Time Created: %(asctime)
#       2. Level of message: %(levelname)s
#       3. Message
if __name__ == "__main__":

    logging.basicConfig(level=logging.INFO, filename="windows.log", filemode="w",
                format="%(asctime)s - %(levelname)s - %(message)s")
    
    level = sys.argv[1]
    message = sys.argv[2]