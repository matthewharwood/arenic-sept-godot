"""Compatibility entry point: rebuild Hunter through the shared hero gallery."""
from pathlib import Path
import runpy
import sys

if __name__ == '__main__':
    if '--hero' not in sys.argv:
        sys.argv.extend(['--hero', 'hunter'])
    runpy.run_path(str(Path(__file__).with_name('build-character-previews.py')), run_name='__main__')
