"""Run mod regressions and optionally compare an installed runtime with the tested baseline."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = (
    'board_progress', 'donation_receipt', 'exact_gear_payment', 'house_data',
    'inventory_model', 'item_quote', 'localization', 'melange_transactions',
    'transactions', 'reward_claim',
)

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-exe', type=Path)
    parser.add_argument('--wps-root', type=Path)
    args = parser.parse_args()
    if bool(args.game_exe) != bool(args.wps_root):
        parser.error('provide both --game-exe and --wps-root')
    commands = [['tools/check_mod.py', '--require-lua']]
    commands += [[f'work/check_{name}.py'] for name in CHECKS]
    failed = []
    for command in commands:
        if subprocess.run([sys.executable, *command], cwd=ROOT, check=False).returncode:
            failed.append(command[0])
    if args.game_exe:
        baseline = json.loads((ROOT / 'tools/runtime-baseline.json').read_text())
        files = {'game': args.game_exe}
        files.update({name: args.wps_root / name for name in baseline if name != 'game'})
        for name, path in files.items():
            if not path.is_file() or digest(path) != baseline[name]:
                failed.append(f'runtime differs or missing: {name}')
        print('Runtime comparison only. Changed builds require targeted in-game verification.')
    else:
        print('Runtime comparison skipped. These checks use simulated game interfaces.')
    for result in failed:
        print(f'FAIL {result}', file=sys.stderr)
    return bool(failed)

if __name__ == '__main__':
    sys.exit(main())

