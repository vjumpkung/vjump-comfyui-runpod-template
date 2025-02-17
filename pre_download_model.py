from ui.main import download
import requests
import argparse


def get_model_list(url: str):
    return requests.get(url).json()


def main(args):
    url = args.input
    try:
        if url:
            downloads_list = get_model_list(url)
            for i in downloads_list:
                download(
                    i["name"],
                    i["url"],
                    i["type"],
                )
            print("Pre-Download Model Complete")
        else:
            print("no download url provided")
            return
    except:
        print("no download url provided")
        return


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pre Download Models")
    parser.add_argument("-i", "--input", required=True, help="URL")
    args = parser.parse_args()
    main(args)
