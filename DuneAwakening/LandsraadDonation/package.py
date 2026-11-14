from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parent
mod = root / 'work/LandsraadDonations'
manifest = mod / 'MANIFEST-SHA256.json'
files = sorted(p for p in mod.rglob('*') if p.is_file() and p != manifest)
hashes = {p.relative_to(mod).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
manifest.write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
archive = root / 'LandsraadDonation-0.2.0-beta.7-Nexus.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
    for path in [*files, manifest]:
        out.write(path, 'LandsraadDonations/' + path.relative_to(mod).as_posix())
with zipfile.ZipFile(archive) as out:
    assert out.testzip() is None
    assert len(out.namelist()) == len(hashes) + 1
    for name, expected in hashes.items():
        assert hashlib.sha256(out.read('LandsraadDonations/' + name)).hexdigest() == expected
print(archive)
