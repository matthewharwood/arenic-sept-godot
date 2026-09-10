#!/usr/bin/env python3
"""Wait for Pages propagation and reject a stale or incomplete release manifest."""
import argparse
import json
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen


def verify(url, commit):
    if urlparse(url).scheme != 'https' or not url.endswith('/'):
        raise ValueError('Expected an HTTPS Pages URL ending in a slash.')
    deadline = time.monotonic() + 240
    last = 'No response'
    while time.monotonic() < deadline:
        request = Request(urljoin(url, f'build-info.json?revision={commit}&time={time.time_ns()}'), headers={'Cache-Control': 'no-cache'})
        try:
            with urlopen(request, timeout=15) as response:
                info = json.load(response)
            if info.get('commit') == commit:
                expected = {'godot': '4.7.2', 'heroes': 8, 'bosses': 8, 'abilities': 32, 'music_version': 3}
                for key, value in expected.items():
                    if info.get(key) != value:
                        raise ValueError(f'Published {key}: expected {value}, got {info.get(key)}')
                print(f'Published revision verified: {commit} at {url}')
                return
            last = f"Still serving revision {info.get('commit')}"
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
            last = str(error)
        time.sleep(5)
    raise RuntimeError(f'Pages did not serve the expected revision: {last}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--commit', required=True)
    args = parser.parse_args()
    verify(args.url, args.commit)
