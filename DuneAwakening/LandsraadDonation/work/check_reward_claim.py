from pathlib import Path
from lupa.lua54 import LuaRuntime

here = Path(__file__).resolve().parent
LuaRuntime().execute(
    (here / 'check_reward_claim.lua').read_text(encoding='utf-8'),
    (here / 'LandsraadDonations/Scripts/reward_claim.lua').as_posix(),
)
print('PASS: reward claim, duplicate click, mismatched response and missing delivery.')
