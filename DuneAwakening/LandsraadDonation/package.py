from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parent
mod = root
manifest = mod / 'MANIFEST-SHA256.json'
folders = ('Icons', 'Locales', 'NBS', 'Scripts', 'Tools', 'UI')
root_files = ('CHANGELOG.txt', 'config.ini', 'mod.json', 'mod.settings.json', 'README-EN.md', 'settings.lua')
files = sorted(
    [mod / name for name in root_files]
    + [p for folder in folders for p in (mod / folder).rglob('*') if p.is_file()]
)
version = json.loads((mod / 'mod.json').read_text(encoding='utf-8'))['version']
hashes = {p.relative_to(mod).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
manifest.write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
archive = root / f'LandsraadDonation-{version}-Nexus.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
    for path in [*files, manifest]:
        out.write(path, 'LandsraadDonations/' + path.relative_to(mod).as_posix())
with zipfile.ZipFile(archive) as out:
    assert out.testzip() is None
    assert len(out.namelist()) == len(hashes) + 1
    for name, expected in hashes.items():
        assert hashlib.sha256(out.read('LandsraadDonations/' + name)).hexdigest() == expected
print(archive)
