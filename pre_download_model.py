import argparse
import os

import dotenv
import requests

dotenv.load_dotenv(override=True)

PORT = os.getenv("PORT") or "8000"


def main(args):
    url = args.input
    try:
        if url:
            r2 = requests.post(
                f"http://localhost:{PORT}/api/download_selected",
                json=[{"name": "Model Pack", "url": url}],
            )

            if r2.status_code == 200:
                print("Pre-Download Model Complete")
            else:
                raise
        else:
            print("no download url provided")
            return
    except:
        exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pre Download Models")
    parser.add_argument("-i", "--input", required=True, help="URL")
    args = parser.parse_args()
    main(args)
