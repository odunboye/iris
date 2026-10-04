#!/usr/bin/env python3
"""Build/test iris-mobile against a real Capacitor bridge, with mocked SDK plugins."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import mobile_util

ROOT = Path(__file__).resolve().parents[1]


def stop_group(process):
    mobile_util.stop_group(process)


def run(args, cwd, timeout=300):
    command = [str(a) for a in args]
    process = subprocess.Popen(command, cwd=cwd, start_new_session=True)
    try:
        code = process.wait(timeout=timeout)
        if code:
            raise subprocess.CalledProcessError(code, command)
    except BaseException:
        stop_group(process)
        raise


def check(capacitor):
    capacitor = Path(capacitor).resolve(strict=True)
    if not (capacitor / 'js/bridge.mjs').is_file():
        raise ValueError('Use hardened capacitor >= 0.2.0')
    # Everything but capacitor already lives in this checkout; no fetch
    # needed (unlike when this ran from Flux, resolving iris-client/
    # iris-mobile meant cloning this repo externally).
    packages = {
        'capacitor': capacitor / 'capacitor.ipkg',
        'iris': ROOT / 'iris.ipkg',
        'iris-client': ROOT / 'client/iris-client.ipkg',
        'iris-mobile': ROOT / 'mobile/iris-mobile.ipkg',
        'iris-mobile-test': ROOT / 'mobile/tests/test.ipkg',
    }
    with tempfile.TemporaryDirectory(prefix='iris-mobile-check-') as directory:
        lines = []
        for name, file in packages.items():
            lines += [f'[custom.all.{name}]', 'type = "local"',
                      'path = ' + json.dumps(str(file.parent)), 'ipkg = ' + json.dumps(file.name)]
        Path(directory, 'pack.toml').write_text('\n'.join(lines) + '\n')
        run(['pack', '--no-prompt', 'build', str(packages['iris-mobile-test'])], cwd=directory)
    run(['node', '--unhandled-rejections=strict', str(ROOT / 'mobile/tests/runtime.mjs'),
         str(capacitor), str(ROOT / 'mobile/tests/build/exec/iris-mobile-test.js')], cwd=ROOT, timeout=30)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capacitor', required=True, type=Path)
    check(parser.parse_args().capacitor)
