import argparse
import os

import dotenv
import requests

import time
import socket

dotenv.load_dotenv(override=True)

PORT = os.getenv("PORT") or "8000"


def main(args):
    url = args.input
    try:

        print("check connection...")

        isSuccess = False
        
        for i in range(10):
            time.sleep(0.5)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(("127.0.0.1", int(PORT)))
            if result == 0:
                isSuccess = True
                break
            sock.close()

        if not isSuccess:
            raise

        if url:
            r2 = requests.post(
                f"http://localhost:{PORT}/api/download_selected",
                json=[{"name": "Model Pack", "url": url}],
            )

            if r2.status_code == 200:
                print("Sending Pre-Download Model List into Queue")
            else:
                raise
        else:
            print("no download url provided")
            return
    except Exception as e:
        print(str(e))
        exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pre Download Models")
    parser.add_argument("-i", "--input", required=True, help="URL")
    args = parser.parse_args()
    main(args)
