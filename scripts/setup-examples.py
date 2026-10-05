#!/usr/bin/env python3
"""Explicitly install optional Idris dependencies for the complete example suite."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capacitor', type=Path, default=ROOT.parent / 'capacitor')
    args = parser.parse_args()
    cap = args.capacitor.resolve()
    if not (cap / 'capacitor.ipkg').is_file():
        parser.error('Provide the full Capacitor bindings checkout with --capacitor PATH')
    packages = {
        'iris': (ROOT, 'iris.ipkg'),
        'iris-client': (ROOT / 'client', 'iris-client.ipkg'),
        'iris-mobile': (ROOT / 'mobile', 'iris-mobile.ipkg'),
        'capacitor': (cap, 'capacitor.ipkg'),
    }
    with tempfile.TemporaryDirectory(prefix='iris-example-deps-') as directory:
        lines = []
        for name, (path, ipkg) in packages.items():
            lines.extend([f'[custom.all.{name}]', 'type = "local"',
                          'path = ' + json.dumps(str(path)), 'ipkg = ' + json.dumps(ipkg)])
        Path(directory, 'pack.toml').write_text('\n'.join(lines) + '\n')
        for package in ['iris-client', 'iris-mobile']:
            subprocess.run(['pack', '--no-prompt', 'install', package], cwd=directory, check=True)


if __name__ == '__main__':
    main()
