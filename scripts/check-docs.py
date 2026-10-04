#!/usr/bin/env python3
"""Check repository Markdown links/anchors and marked complete Idris examples."""
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = re.compile(r'<!-- iris-example: ([^\n]+) -->\s*```idris\n(.*?)\n```', re.S)


def without_fences(text):
    return re.sub(r'^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$', '', text, flags=re.M | re.S)


def anchors(text):
    counts, result = {}, set()
    for line in without_fences(text).splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*\s*$', line)
        if not match:
            continue
        title = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', match[1])
        title = re.sub(r'<[^>]+>', '', title).replace('`', '').lower()
        slug = re.sub(r'[^\w\- ]', '', title).replace(' ', '-')
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.add(slug + (f'-{count}' if count else ''))
    result.update(re.findall(r'<(?:a|[a-z]+)\s+[^>]*id=["\']([^"\']+)', text))
    return result


def destinations(text):
    text = without_fences(text)
    text = re.sub(r'`[^`\n]*`', '', text)
    for match in re.finditer(r'!?\[[^]\n]*\]\((<[^>]+>|[^\s)]+)(?:\s+["\'][^\n]*?["\'])?\)', text):
        yield match[1].strip('<>')
    for match in re.finditer(r'^\s*\[[^]]+\]:\s*(<[^>]+>|\S+)', text, re.M):
        yield match[1].strip('<>')


def link_errors(path, root=ROOT):
    errors = []
    for destination in destinations(path.read_text()):
        parts = urlsplit(destination)
        if parts.scheme or parts.netloc:
            continue
        target = (root / unquote(parts.path.lstrip('/'))) if parts.path.startswith('/') else (path.parent / unquote(parts.path))
        if not target.exists():
            errors.append(f'{path.relative_to(root)}: missing target {destination}')
        elif parts.fragment and target.suffix == '.md' and unquote(parts.fragment) not in anchors(target.read_text()):
            errors.append(f'{path.relative_to(root)}: missing heading {destination}')
    return errors


def examples(root=ROOT):
    found = {}
    for path in sorted((root / 'docs').rglob('*.md')):
        text = path.read_text()
        matches = EXAMPLE.findall(text)
        if text.count('<!-- iris-example:') != len(matches):
            raise ValueError(f'Malformed example marker in {path.relative_to(root)}')
        for name, source in matches:
            relative = Path(name)
            if relative.is_absolute() or '..' in relative.parts or relative.suffix != '.idr':
                raise ValueError(f'Unsafe Idris example path: {name}')
            if name in found:
                raise ValueError(f'Duplicate Idris example path: {name}')
            found[name] = source + '\n'
    return found


def main():
    paths = set(ROOT.glob('*.md'))
    for directory in ['docs', 'examples', 'client', 'mobile']:
        paths.update(p for p in (ROOT / directory).rglob('*.md')
                     if not {'build', 'node_modules', '.workspace'} & set(p.relative_to(ROOT).parts))
    errors = [error for path in sorted(paths) for error in link_errors(path)]
    try:
        snippets = examples()
        for required in ['src/Greeter.idr', 'src/MainWeb.idr', 'src/MainMobile.idr', 'src/RequestExample.idr']:
            if required not in snippets:
                errors.append(f'Missing marked tutorial example: {required}')
    except ValueError as error:
        errors.append(str(error))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'Documentation links and examples validated ({len(paths)} Markdown files).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
