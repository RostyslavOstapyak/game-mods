"""Read-only mod validation. Never imports/runs mod scripts or contacts the game."""
import argparse
import configparser
import json
from pathlib import Path
import re
import sys

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--require-lua', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    failures = []
    report = {'root': str(root), 'game_actions': False}
    if not (root / 'mod.json').is_file():
        parser.error('Choose the mod directory containing mod.json')
    for path in root.rglob('*.json'):
        try:
            json.loads(path.read_text(encoding='utf-8-sig'))
        except Exception as error:
            failures.append(f'{path.name}: {error}')
    try:
        from lupa.lua54 import LuaRuntime
    except ImportError:
        report['lua_syntax'] = 'NOT CHECKED: install lupa in the development environment'
        if args.require_lua:
            failures.append('Lua syntax checker unavailable')
    else:
        lua = LuaRuntime(unpack_returned_tuples=True)
        files = sorted((root / 'Scripts').glob('*.lua'))
        for path in files:
            try:
                lua.execute('assert(loadfile(...))', str(path))
            except Exception as error:
                failures.append(f'{path.name}: {error}')
        report['lua_files_compiled_without_execution'] = len(files)
    packs = {}
    for code in ('source', 'en', 'uk'):
        path = root / 'Locales' / (code + '.tsv')
        if not path.exists():
            continue
        pack = {}
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if not line or line.startswith('#'):
                continue
            fields = line.split('\t', 1)
            if len(fields) != 2 or fields[0] in pack:
                failures.append(f'{code}: invalid or duplicate key')
                continue
            pack[fields[0]] = fields[1]
        packs[code] = pack
    if packs:
        base = packs.get('source', packs.get('en', {}))
        for code, pack in packs.items():
            for key in base.keys() - pack.keys():
                failures.append(f'{code}: missing key {key}')
            for key in base.keys() & pack.keys():
                if re.findall(r'%[ds]', base[key]) != re.findall(r'%[ds]', pack[key]):
                    failures.append(f'{code}: placeholder mismatch {key}')
        for path in (root / 'Scripts').glob('*.lua'):
            for key in re.findall(r"L\.t\('([^']+)'\)", path.read_text(encoding='utf-8-sig')):
                if key not in packs.get('en', {}):
                    failures.append(f'{path.name}: unknown language key {key}')
        report['translation_keys'] = len(base)
    for path in (root / 'Scripts').glob('*.lua'):
        for name in re.findall(r"'([a-z0-9_-]+\.png)'", path.read_text(encoding='utf-8-sig')):
            if not (root / 'UI' / name).is_file():
                failures.append(f'{path.name}: missing UI/{name}')
    definition = root / 'NBS' / 'item.ini'
    if definition.exists():
        ini = configparser.ConfigParser(interpolation=None, delimiters=('=',), strict=False)
        ini.read(definition, encoding='utf-8-sig')
        icon = ini.get('item', 'icon_file', fallback='').strip()
        if icon and not (root / icon).is_file():
            failures.append('Missing buildable icon: ' + icon)
    report['failures'] = failures
    report['result'] = 'FAIL' if failures else 'PASS (only checks listed above)'
    print(json.dumps(report, ensure_ascii=True, indent=2))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
