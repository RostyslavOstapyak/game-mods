from pathlib import Path
import sys
sys.path.insert(0,'work/lua-check')
from lupa.lua54 import LuaRuntime
harness=Path('work/check_exact_gear_payment.lua').read_text(encoding='utf-8')
cases=['one_of_two','two_types','partial_stack','no_removal','unselected_changed','equipment_changed','bad_uid','missing_checksum']
for mode in cases:
    lua=LuaRuntime(unpack_returned_tuples=True)
    assert lua.execute(harness,Path('work/LandsraadDonations/Scripts').resolve().as_posix(),mode),mode
print('PASS: 8 exact adapter cases: one of duplicates, separate equipment, multiple types, partial stack, changed inventory/equipment, ID precision and no repeat on failed receipt.')
