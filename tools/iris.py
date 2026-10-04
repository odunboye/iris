#!/usr/bin/env python3
"""Iris Capacitor packaging CLI; packages a compiled Iris application for a
Capacitor WebView. Moved here from Flux (as `flux mobile ...`) since it has
no dependency on Flux's server - it packages whatever UI application you
point it at, built on `iris.mobile.json`-shaped configuration."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import tomllib
import uuid
import mobile_check
import mobile_policy
import mobile_native

ROOT = Path(__file__).resolve().parents[1]
TOOLING = ROOT / 'tooling'
EXTENSIONS = {'.html', '.css', '.png', '.jpg', '.jpeg', '.svg', '.webp', '.gif', '.ico', '.woff', '.woff2', '.ttf'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate configuration key: ' + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique)


def atomic_json(path, value):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        temporary.write_text(json.dumps(value, indent=2) + '\n')
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def inside(root, relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute() or '..' in Path(relative).parts:
        raise ValueError('Expected a contained relative path')
    candidate = root / relative
    # Reject symlinks, including ones pointing back into the tree.
    if any(p.is_symlink() for p in [candidate, *candidate.parents] if p != root.parent and p.is_relative_to(root)):
        raise ValueError('Symlinks are not mobile inputs/outputs: ' + relative)
    resolved = candidate.resolve()
    if not resolved.is_relative_to(root.resolve()) or resolved == root.resolve():
        raise ValueError('Path escapes its owner: ' + relative)
    return candidate


def capacitor_config_path():
    base = Path(os.environ.get('XDG_CONFIG_HOME') or (Path.home() / '.config'))
    return base / 'iris/capacitor-path'


def remember_capacitor(path):
    config = capacitor_config_path()
    config.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(config, (str(Path(path).expanduser().resolve()) + '\n').encode())


def remembered_capacitor():
    config = capacitor_config_path()
    if config.is_file():
        text = config.read_text().strip()
        if text:
            return Path(text)
    return None


CAPACITOR_URL = 'https://github.com/odunboye/capacitor.git'


def default_capacitor_cache():
    base = Path(os.environ.get('XDG_CACHE_HOME') or (Path.home() / '.cache'))
    return base / 'iris/capacitor'


def default_capacitor():
    # pack's own git-dependency cache only fetches what Idris compilation needs
    # (the ipkg manifest and modules it imports), not a full raw checkout - no
    # good for running npm against or reading native/JS plugin files. Clone and
    # set this up for real instead, the same way ./iris setup --capacitor would.
    cache = default_capacitor_cache()
    if not cache.is_dir():
        cache.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--depth', '1', CAPACITOR_URL, str(cache)], check=True)
        print(f'Cloned {CAPACITOR_URL} to {cache}')
    cap = library(cache)
    run(['npm', 'ci', '--ignore-scripts'], cap)
    run(['npm', 'ci', '--ignore-scripts'], TOOLING)
    remember_capacitor(cap)
    return cap


def library(path):
    path = Path(path).resolve(strict=True)
    package = read_json(path / 'package.json')
    if not isinstance(package, dict) or package.get('version') not in ['0.2.0', '0.3.0'] or not (path / 'js/register.mjs').is_file():
        raise ValueError('Expected hardened capacitor 0.2.0 or 0.3.0')
    return path


def configuration(project, override=None, require_entry=True):
    project = project.resolve(strict=True)
    file = Path(override).resolve(strict=True) if override else project / 'iris.mobile.json'
    cfg = read_json(file)
    required = {'format', 'appId', 'appName', 'capacitor', 'webDir', 'entry', 'assets'}
    if not isinstance(cfg, dict) or type(cfg.get('format')) is not int or cfg['format'] not in [1, 2]:
        raise ValueError('Expected format-1 or format-2 iris.mobile.json')
    if cfg['format'] == 2:
        required = required | {'apiOrigin'}
    if not required <= set(cfg) or set(cfg) - required - {'ui'}:
        raise ValueError('Invalid mobile configuration keys; format 2 requires apiOrigin')
    if cfg['format'] == 2:
        mobile_policy.api_origin(cfg['apiOrigin'])
    if not isinstance(cfg['appId'], str) or not re.fullmatch(r'[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*){2,}', cfg['appId']):
        raise ValueError('appId must be a reverse-domain identifier')
    if not isinstance(cfg['appName'], str) or not cfg['appName'].strip() or not re.fullmatch(r'[\w .()-]{1,80}', cfg['appName']):
        raise ValueError('Invalid appName')
    if not isinstance(cfg['capacitor'], str):
        raise ValueError('capacitor must identify a library checkout')
    cap = library(project / cfg['capacitor'])
    web = inside(project, cfg['webDir'])
    entry = inside(project, cfg['entry'])
    if not web.is_dir() or (require_entry and not entry.is_file()):
        raise ValueError('Build the web application first; webDir/entry are missing')
    if web.is_relative_to(project / '.workspace/mobile'):
        raise ValueError('Mobile output cannot also be its input')
    if not isinstance(cfg['assets'], list) or not cfg['assets'] or any(not isinstance(p, str) for p in cfg['assets']):
        raise ValueError('assets must be an explicit nonempty list of public file globs')
    return project, cfg, cap, web, entry


def snapshot(web, entry, cfg, cap):
    files = {}
    for pattern in cfg['assets']:
        if Path(pattern).is_absolute() or '..' in Path(pattern).parts or '**' in pattern:
            raise ValueError('Unsafe public asset glob')
        for file in sorted(web.glob(pattern)):
            file = inside(web, file.relative_to(web).as_posix())
            if not file.is_file() or file.suffix.lower() not in EXTENSIONS or any(p.startswith('.') for p in file.relative_to(web).parts):
                raise ValueError('Only public web assets may be packaged: ' + str(file))
            files[file.relative_to(web).as_posix()] = file.read_bytes()
    if 'index.html' not in files:
        raise ValueError('assets must include index.html')
    # The initial contract deliberately accepts one known application entry.
    html = files['index.html'].decode('utf-8')
    if cfg['format'] == 2:
        html = mobile_policy.bind_csp(html, cfg['apiOrigin'])
    pattern = r'<script\s+(?:type=[\"\']module[\"\']\s+)?src=[\"\']app\.js[\"\']\s*></script>'
    if len(re.findall(pattern, html)) != 1:
        raise ValueError('index.html must contain exactly one app.js entry script')
    files['index.html'] = re.sub(pattern, '<script type="module" src="app.js"></script>', html).encode()
    source = entry.read_bytes()
    fingerprint = digest(json.dumps(cfg, sort_keys=True).encode() + source +
        b''.join(name.encode() + b'\0' + digest(data).encode() for name, data in sorted(files.items())) +
        (cap / 'package-lock.json').read_bytes() +
        b''.join(p.relative_to(cap).as_posix().encode() + b'\0' + digest(inside(cap, p.relative_to(cap).as_posix()).read_bytes()).encode()
                 for p in sorted((cap / 'js').glob('*.mjs'))) +
        b''.join(name.encode() + b'\0' + digest(data).encode() for name, data in mobile_native.plugin_files(cap).items()) +
        (TOOLING / 'package-lock.json').read_bytes() + (TOOLING / 'bundle.mjs').read_bytes() +
        (TOOLING / 'rpc.mjs').read_bytes() + Path(mobile_policy.__file__).read_bytes() + Path(mobile_native.__file__).read_bytes())
    return files, source, fingerprint


def workspace(project):
    directory = inside(project, '.workspace/mobile')
    if directory.exists():
        marker = inside(directory, 'owner.json')
        if not marker.is_file() or read_json(marker) != {'format': 1, 'project': str(project)}:
            raise ValueError('Refusing to use an unowned mobile output directory')
    else:
        directory.mkdir(parents=True)
        atomic_json(directory / 'owner.json', {'format': 1, 'project': str(project)})
    return directory


@contextlib.contextmanager
def exclusive(project):
    # Advisory process lock is released by the OS even after interruption.
    try:
        import fcntl
    except ImportError:
        raise ValueError('Mobile preview tooling currently requires macOS or Linux')
    directory = workspace(project.resolve(strict=True))
    with inside(directory, 'operation.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another mobile operation owns this project')
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def run(args, cwd):
    mobile_check.run(args, cwd)


def compile_ui(project, override=None):
    project, cfg, cap, _, _ = configuration(project, override, require_entry=False)
    ui = cfg.get('ui') or read_json(project / 'flux.json')['ui']
    package = inside(project, ui)
    config = tomllib.loads((project / 'pack.toml').read_text())
    paths = {}
    for name, spec in config.get('custom', {}).get('all', {}).items():
        if spec.get('type') != 'local':
            raise ValueError('Mobile compile currently requires a local managed Pack map')
        paths[name] = ((project / spec['path']).resolve(), spec['ipkg'])
    # iris-client/iris-mobile live in this checkout, alongside this script;
    # registered here as local paths, since iris-mobile isn't registered in
    # a user project's own Pack map by default (nothing in an ordinary
    # project's build graph depends on it directly).
    for name, path, ipkg in [('capacitor', cap, 'capacitor.ipkg'),
                             ('iris-client', ROOT / 'client', 'iris-client.ipkg'),
                             ('iris-mobile', ROOT / 'mobile', 'iris-mobile.ipkg')]:
        if name in paths and paths[name] != (path, ipkg):
            raise ValueError('Conflicting optional package registration: ' + name)
        paths[name] = (path, ipkg)
    collection = config.get('collection')
    with tempfile.TemporaryDirectory(prefix='iris-compile-') as directory:
        lines = ['collection = ' + json.dumps(collection)] if collection else []
        for name, (path, ipkg) in paths.items():
            if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
                raise ValueError('Invalid Pack package name')
            lines += [f'[custom.all.{name}]', 'type = "local"',
                      'path = ' + json.dumps(str(path)), 'ipkg = ' + json.dumps(ipkg)]
        Path(directory, 'pack.toml').write_text('\n'.join(lines) + '\n')
        run(['pack', '--no-prompt', '--cg', 'javascript', 'build', package], directory)


def build(project, override=None):
    project, cfg, cap, web, entry = configuration(project, override)
    files, source, fingerprint = snapshot(web, entry, cfg, cap)
    if not (TOOLING / 'node_modules/esbuild').is_dir() or not (cap / 'node_modules/@capacitor/core').is_dir():
        raise ValueError('Run ./iris setup --capacitor PATH first')
    directory = workspace(project)
    releases = inside(directory, 'releases')
    releases.mkdir(exist_ok=True)
    release = releases / uuid.uuid4().hex
    with tempfile.TemporaryDirectory(prefix='stage-', dir=directory) as stage:
        stage = Path(stage)
        public = stage / 'www'
        public.mkdir()
        for name, data in files.items():
            target = inside(public, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        # Compile a frozen copy, not a concurrently changing application entry.
        frozen = stage / 'application.js'
        frozen.write_bytes(source)
        boot = stage / 'mobile-config.mjs'
        boot.write_text('import {createRpcTransport} from ' + json.dumps(str(TOOLING / 'rpc.mjs')) + ';\n' +
            'const config = Object.freeze(' + json.dumps({'format': cfg['format'], 'apiOrigin': cfg.get('apiOrigin')}) + ');\n' +
            'Object.defineProperty(globalThis, "IrisMobile", {value: config});\n' +
            ('Object.defineProperty(globalThis, "IrisMobileTransport", {value: createRpcTransport(config.apiOrigin)});\n' if cfg['format'] == 2 else ''))
        run(['node', TOOLING / 'bundle.mjs', cap / 'js/register.mjs', frozen, public / 'app.js', boot], TOOLING)
        hashes = {file.relative_to(public).as_posix(): digest(file.read_bytes()) for file in sorted(public.rglob('*')) if file.is_file()}
        shutil.move(str(public), str(release))
        atomic_json(directory / 'build.json', {'format': 1, 'release': release.name, 'fingerprint': fingerprint, 'files': hashes})
    print('Built mobile web release: ' + str(release))
    return release


def built(project, override=None):
    project, cfg, cap, web, entry = configuration(project, override)
    _, _, fingerprint = snapshot(web, entry, cfg, cap)
    directory = workspace(project)
    manifest = read_json(directory / 'build.json')
    if not isinstance(manifest, dict) or set(manifest) != {'format', 'release', 'fingerprint', 'files'}:
        raise ValueError('Invalid mobile build manifest')
    if type(manifest['format']) is not int or manifest['format'] != 1 or not isinstance(manifest['release'], str) or not isinstance(manifest['files'], dict):
        raise ValueError('Invalid mobile build manifest')
    if manifest['fingerprint'] != fingerprint or not re.fullmatch('[0-9a-f]{32}', manifest['release']):
        raise ValueError('Mobile bundle is stale; run ./iris build')
    release = inside(directory, 'releases/' + manifest['release'])
    for file in release.rglob('*'):
        inside(release, file.relative_to(release).as_posix())
        if not file.is_file() and not file.is_dir():
            raise ValueError('Unexpected mobile release entry')
    actual = {file.relative_to(release).as_posix(): digest(inside(release, file.relative_to(release).as_posix()).read_bytes())
              for file in release.rglob('*') if file.is_file()}
    if not actual or actual != manifest.get('files'):
        raise ValueError('Mobile bundle integrity check failed')
    return directory, cfg, release


def sync(project, platform, override=None):
    directory, cfg, release = built(project, override)
    host = inside(directory, 'native')
    owner = {'format': 1, 'project': str(project.resolve())}
    if host.exists():
        marker = inside(host, 'owner.json')
        if not marker.is_file() or read_json(marker) != owner:
            raise ValueError('Refusing to overwrite an unowned native host')
    else:
        host.mkdir()
        atomic_json(host / 'owner.json', owner)
    native_config = {'appId': cfg['appId'], 'appName': cfg['appName'], 'webDir': 'www'}
    quiet_config = dict(native_config, loggingBehavior='none')
    target = inside(host, 'capacitor.config.json')
    if target.exists() and read_json(target) not in [native_config, quiet_config]:
        raise ValueError('Native identity/configuration changed; refusing to overwrite the existing host')
    atomic_json(target, quiet_config)
    cap = library(project / cfg['capacitor'])
    mobile_native.dependencies(host, cap, TOOLING, run, inside, atomic_json)
    # SDK input changes during npm staging must not silently change this release.
    built(project, override)
    public = inside(host, 'www')
    with tempfile.TemporaryDirectory(prefix='web-stage-', dir=host) as temporary:
        new = Path(temporary) / 'www'
        previous = Path(temporary) / 'previous'
        shutil.copytree(release, new)
        if public.exists():
            public.rename(previous)
        try:
            new.rename(public)
        except BaseException:
            if previous.exists():
                previous.rename(public)
            raise
    run(['npm', 'ci', '--ignore-scripts'], host)
    cli = host / 'node_modules/@capacitor/cli/bin/capacitor'
    if not inside(host, platform).exists():
        run(['node', cli, 'add', platform], host)
    run(['node', cli, 'sync', platform], host)
    print('Synced native project: ' + str(host / platform))
    return host, cli


def atomic_write(path, data):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        temporary.write_bytes(data)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


NEW_TARGETS = {
    'web':      ('MainWeb',    'Iris.Backend.Web.DOM.Run', 'runWeb'),
    'terminal': ('Main',       'Iris.Backend.Terminal.Run', 'runTUI'),
    'canvas':   ('MainCanvas', 'Iris.Backend.Canvas.Run', 'runCanvas'),
    'mobile':   ('MainMobile', 'Iris.Backend.Canvas.Run', 'runMobile'),
}


def new_write(path, text, force):
    if path.exists() and not force:
        raise ValueError('Refusing to overwrite existing file (use --force): ' + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print('Wrote ' + str(path))


def default_app_id(name):
    segment = re.sub(r'[^a-z0-9]', '', name.lower())
    if not segment or not segment[0].isalpha():
        segment = 'app' + segment
    return f'com.example.{segment}'


def new_target(project, target, module, app_value, name, force, capacitor=None, app_id=None, app_name=None):
    if target == 'mobile' and capacitor is None:
        raise ValueError('--target mobile requires --capacitor')
    if target == 'mobile' and app_id is None:
        app_id = default_app_id(name)
        print(f"No --app-id given - defaulting to '{app_id}'; change it before a real release.")
    project = project.resolve(strict=True)
    sourcedir = next((d for d in ['.', 'src'] if (project / d / (module + '.idr')).is_file()), None)
    if sourcedir is None:
        raise ValueError(f'No {module}.idr in {project} or {project}/src - extract your model/update/view '
                          f'into a module exporting `{app_value} : UIApp model msg` first, then try again.')
    entry_module, runner_import, runner_call = NEW_TARGETS[target]
    new_write(project / sourcedir / (entry_module + '.idr'),
              f'module {entry_module}\n\nimport {module}\nimport {runner_import}\n\n'
              f'main : IO ()\nmain = {runner_call} {app_value}\n', force)

    executable = f'{name}-{target}'
    ipkg = [f'package iris-{name}-{target}', 'depends = iris', f'sourcedir = "{sourcedir}"',
            f'main = {entry_module}', f'executable = {executable}']
    if target == 'terminal':
        app_dir = f'build/exec/{executable}_app'
        c_source = str(ROOT / 'c/iristui.c')
        ipkg.append('prebuild = "mkdir -p ' + app_dir + ' && cc -dynamiclib ' + c_source + ' -o ' + app_dir +
                    '/libiristui.dylib 2>/dev/null || cc -shared -fPIC ' + c_source + ' -o ' + app_dir + '/libiristui.so"')
    new_write(project / (target + '.ipkg'), '\n'.join(ipkg) + '\n', force)

    title = app_name or name
    if target == 'web':
        new_write(project / 'index.html',
                  '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
                  '<meta name="viewport" content="width=device-width,initial-scale=1">'
                  f'<title>{title}</title></head><body><main id="iris-app"></main>'
                  f'<script src="build/exec/{executable}"></script></body></html>\n', force)
    elif target == 'canvas':
        new_write(project / 'canvas.html',
                  '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
                  '<meta name="viewport" content="width=device-width,initial-scale=1">'
                  f'<title>{title}</title><link rel="stylesheet" href="canvas.css"></head><body>'
                  '<canvas id="iris-canvas" width="640" height="480"></canvas>'
                  f'<script src="build/exec/{executable}"></script></body></html>\n', force)
        new_write(project / 'canvas.css',
                  'html,body{margin:0;width:100%;height:100%;overflow:hidden}'
                  '#iris-canvas{display:block;width:100%;height:100%;touch-action:none}\n', force)
    elif target == 'mobile':
        new_write(project / 'public/index.html',
                  '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
                  '<meta name="viewport" content="width=device-width,initial-scale=1">'
                  f'<title>{title}</title></head><body><canvas id="iris-canvas"></canvas>'
                  '<script src="app.js"></script></body></html>\n', force)
        config_path = project / 'iris.mobile.json'
        if config_path.exists() and not force:
            raise ValueError('Refusing to overwrite existing file (use --force): ' + str(config_path))
        atomic_json(config_path, {
            'format': 1, 'appId': app_id, 'appName': title,
            'capacitor': str(Path(capacitor).expanduser().resolve()),
            'webDir': 'public', 'entry': f'build/exec/{executable}',
            'ui': target + '.ipkg', 'assets': ['index.html', '*.css'],
        })
        print('Wrote ' + str(config_path))
        try:
            config = tomllib.loads((project / 'pack.toml').read_text())
            non_local = [n for n, spec in config.get('custom', {}).get('all', {}).items() if spec.get('type') != 'local']
        except FileNotFoundError:
            non_local = ['(no pack.toml found)']
        if non_local:
            print('Note: ./iris compile/build requires every pack.toml custom.all entry to be '
                  'type = "local", including iris itself - currently not true for: ' + ', '.join(non_local))


STARTER_MODULE = '''module {module}

import Iris

data Msg = Increment

update : Msg -> Nat -> (Nat, Cmd Msg)
update Increment count = (S count, none)

view : Nat -> Widget Msg
view count = vstack
  [ text ("Count: " ++ show count)
  , button "Increment" Increment
  ]

export
{app_value} : UIApp Nat Msg
{app_value} = MkApp (0, none) update view (\\_, _ => Nothing) Nothing
'''


def git_iris_origin():
    def git(*args):
        return subprocess.run(['git', '-C', str(ROOT), *args], check=True, capture_output=True, text=True).stdout.strip()
    return git('remote', 'get-url', 'origin'), git('rev-parse', 'HEAD')


def register_target(pack_toml, name, target):
    section = f'[custom.all.{name}-{target}]'
    text = pack_toml.read_text()
    if section not in text:
        pack_toml.write_text(text.rstrip('\n') + f'\n\n{section}\ntype = "local"\npath = "."\nipkg = "{target}.ipkg"\n')
        print(f'Registered {name}-{target} in pack.toml')


def build_hint(name, targets):
    print(f"'{name}' is ready. Next: pack --no-prompt install iris && "
          + ' && '.join(f'pack --no-prompt{" --cg javascript" if t != "terminal" else ""} build {t}.ipkg' for t in targets))


def new_project(project, name, targets, module, app_value, capacitor=None, app_id=None, app_name=None):
    project = Path(project).expanduser().resolve()
    if project.exists():
        raise ValueError(f'{project} already exists - use ./iris add from inside it to add a target, '
                          'or remove it first.')
    project.mkdir(parents=True)
    (project / 'src').mkdir()
    module_file = project / 'src' / (module + '.idr')
    new_write(module_file, STARTER_MODULE.format(module=module, app_value=app_value), force=False)
    print(f'Starter module - edit {module_file} to build your actual app.')
    url, commit = git_iris_origin()
    pack_toml = project / 'pack.toml'
    new_write(pack_toml, f'[custom.all.iris]\ntype = "git"\nurl = "{url}"\ncommit = "{commit}"\nipkg = "iris.ipkg"\n',
              force=False)
    for target in targets:
        new_target(project, target, module, app_value, name, force=False,
                  capacitor=capacitor, app_id=app_id, app_name=app_name)
        register_target(pack_toml, name, target)
    build_hint(name, targets)


def add_targets(targets, module, app_value, force, capacitor=None, app_id=None, app_name=None):
    project = Path.cwd()
    pack_toml = project / 'pack.toml'
    if not pack_toml.is_file():
        raise ValueError(f'No pack.toml in {project} - this is not an iris project; '
                          'run ./iris new <name> first.')
    name = project.name
    for target in targets:
        new_target(project, target, module, app_value, name, force,
                  capacitor=capacitor, app_id=app_id, app_name=app_name)
        register_target(pack_toml, name, target)
    build_hint(name, targets)


def install_cli(directory, force=False):
    directory = Path(directory).expanduser().resolve()
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'iris'
    if target == (ROOT / 'iris').resolve():
        print('The checkout already provides this launcher: ' + str(target))
        return
    if target.is_dir():
        raise ValueError('Refusing to replace a directory with a CLI launcher: ' + str(target))
    backup = None
    launcher = ('#!/bin/sh\nexec ' + shlex.quote(str(ROOT / 'iris')) + ' "$@"\n').encode()
    if target.exists() or target.is_symlink():
        if target.is_file() and target.read_bytes() == launcher:
            target.chmod(0o755)
            print('Iris CLI already installed: ' + str(target))
            return
        if not force:
            raise ValueError('A different iris command exists at ' + str(target) + '; use --force to back it up and replace it')
        backup = directory / ('iris.backup-' + uuid.uuid4().hex)
        target.rename(backup)
        print('Previous launcher backed up: ' + str(backup))
    try:
        atomic_write(target, launcher)
        target.chmod(0o755)
    except BaseException:
        target.unlink(missing_ok=True)
        if backup is not None:
            backup.rename(target)
        raise
    print('Installed Iris CLI: ' + str(target) + '; ensure this directory is on PATH')


def main(argv=None):
    parser = argparse.ArgumentParser(prog='iris', description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    installer = commands.add_parser('install-cli', help='install this launcher onto PATH')
    installer.add_argument('--bin-dir', default='~/.local/bin')
    installer.add_argument('--force', action='store_true')
    newer = commands.add_parser('new', help='create a new project from nothing (like `pack new bin`)')
    newer.add_argument('name', help='project directory name and package/executable base name')
    newer.add_argument('--target', nargs='+', choices=sorted(NEW_TARGETS), default=None,
                       help='targets to scaffold (default: web and mobile; mobile is dropped if no '
                            'capacitor checkout is known and none can be cloned automatically)')
    newer.add_argument('--project', type=Path, help="project directory (default: ./<name>)")
    newer.add_argument('--module', help='shared module to generate, exporting `app_value : UIApp model msg` '
                                        '(default: <Name>)')
    newer.add_argument('--app-value', default='app', help='name of the exported UIApp value in --module (default: app)')
    newer.add_argument('--capacitor', type=Path, help='capacitor checkout; enables the mobile target '
                                                       '(default: remembered from the last ./iris setup, '
                                                       'or cloned automatically)')
    newer.add_argument('--app-id', help='reverse-domain app id for the mobile target '
                                        '(default: com.example.<name>; change it before a real release)')
    newer.add_argument('--app-name', help='human-readable app name; defaults to <name>')
    adder = commands.add_parser('add', help='add a target to the project in the current directory')
    adder.add_argument('target', nargs='+', choices=sorted(NEW_TARGETS))
    adder.add_argument('--module', help='shared module exporting `app_value : UIApp model msg` '
                                        '(default: the current directory name, capitalized)')
    adder.add_argument('--app-value', default='app', help='name of the exported UIApp value in --module (default: app)')
    adder.add_argument('--capacitor', type=Path, help='capacitor checkout; required for the mobile target '
                                                       '(default: remembered from the last ./iris setup, '
                                                       'or cloned automatically)')
    adder.add_argument('--app-id', help='reverse-domain app id for the mobile target '
                                        '(default: com.example.<current directory name>; change it '
                                        'before a real release)')
    adder.add_argument('--app-name', help='human-readable app name; defaults to the current directory name')
    adder.add_argument('--force', action='store_true', help='overwrite existing generated files')
    for name, help in [('setup', 'install locked npm dependencies for the library and this tooling'),
                        ('check', 'build and run the compiled Idris adapter test against the hardened bridge'),
                        ('compile', 'build the selected UI target only'),
                        ('build', 'package web assets and a frozen application entry into a release'),
                        ('sync', 'create/update the owned native host and sync one platform'),
                        ('open', 'sync, then open the native project in its platform IDE'),
                        ('run', 'sync, then run the native project on a device/emulator')]:
        sub = commands.add_parser(name, help=help)
        if name in ['setup', 'check']:
            sub.add_argument('--capacitor', type=Path, required=True, help='library checkout')
        else:
            sub.add_argument('--project', type=Path, default=Path.cwd())
            sub.add_argument('--config', type=Path, help='explicit configuration file; paths still resolve relative to --project')
            if name in ['sync', 'open', 'run']:
                sub.add_argument('platform', choices=['ios', 'android'])
    args = parser.parse_args(argv)
    if args.command == 'install-cli':
        install_cli(args.bin_dir, args.force)
        return
    if args.command in ['new', 'add']:
        try:
            capacitor = args.capacitor or remembered_capacitor()
            if args.command == 'new':
                project = args.project or (Path.cwd() / args.name)
                module = args.module or (args.name[0].upper() + args.name[1:])
                if args.target:
                    if 'mobile' in args.target and capacitor is None:
                        capacitor = default_capacitor()
                    targets = args.target
                else:
                    # web + mobile by default; mobile only drops out if no
                    # capacitor is known and none can be cloned right now
                    # (e.g. offline) - that shouldn't block scaffolding web.
                    if capacitor is None:
                        try:
                            capacitor = default_capacitor()
                        except (OSError, subprocess.SubprocessError) as error:
                            print(f'Could not set up a capacitor checkout automatically ({error}) - '
                                  'scaffolding web only; run ./iris add mobile once one is available.')
                    targets = ['web', 'mobile'] if capacitor else ['web']
                new_project(project, args.name, targets, module, args.app_value,
                           capacitor, args.app_id, args.app_name)
            else:
                if 'mobile' in args.target and capacitor is None:
                    capacitor = default_capacitor()
                module = args.module or (Path.cwd().name[0].upper() + Path.cwd().name[1:])
                add_targets(args.target, module, args.app_value, args.force,
                           capacitor, args.app_id, args.app_name)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            parser.exit(1, str(error) + '\n')
        return
    try:
        if args.command in ['setup', 'check']:
            cap = library(args.capacitor)
            remember_capacitor(cap)
            if args.command == 'check':
                mobile_check.check(cap)
            else:
                run(['npm', 'ci', '--ignore-scripts'], cap)
                run(['npm', 'ci', '--ignore-scripts'], TOOLING)
        else:
            with exclusive(args.project):
                if args.command == 'compile':
                    compile_ui(args.project, args.config)
                elif args.command == 'build':
                    build(args.project, args.config)
                else:
                    host, cli = sync(args.project, args.platform, args.config)
                    if args.command != 'sync':
                        run(['node', cli, args.command, args.platform], host)
    except KeyboardInterrupt:
        parser.exit(130, 'Stopped mobile operation. Native SDK effects are not rolled back.\n')
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, (type(error).__name__ if isinstance(error, subprocess.SubprocessError) else str(error)) + '\n')


if __name__ == '__main__':
    main()
