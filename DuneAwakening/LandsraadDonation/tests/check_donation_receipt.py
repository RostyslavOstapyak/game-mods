from pathlib import Path
import sys,tempfile
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
reader=lua.execute('return dofile(...)',Path('Scripts/donation_receipt.lua').resolve().as_posix())
journal='''2026-10-27T09:37:51Z 123-456 prepared house=DA_HouseTseida term=6 cost=2 points=96 balance=176168034 personal_before=2048 rate=1000
2026-10-27T09:37:51Z 123-456 payment=items template=gear_batch item_before=2 units=2
2026-10-27T09:37:51Z 123-456 xp_planned track=2 before=2048 amount=96 rate=1 level=14.4
2026-10-27T09:38:08Z 123-456 confirmed personal_after=2144 balance=176168034
2026-10-27T09:38:09Z 123-456 xp_confirmed track=2 after=2144
'''
with tempfile.TemporaryDirectory()as tmp:
    root=Path(tmp)
    def read(state,text):
        (root/'transaction-state.log').write_text(state,encoding='utf-8')
        (root/'transactions.log').write_text(text,encoding='utf-8')
        return reader.latest(root.resolve().as_posix())
    result=read('123-456 begin\n123-456 complete\n',journal)
    assert result.points==96 and result.xp==96 and result.units==2 and result.kind=='items'
    assert read('123-456 begin\n',journal) is None
    assert read('123-456 begin\n123-456 refunded\n',journal) is None
    assert read('123-456 complete\n',journal.replace('personal_after=2144','personal_after=2145')) is None
    assert read('123-456 complete\n',journal[:journal.rfind('2026-10-27T09:38:09Z')]) is None
    assert read('999-000 complete\n',journal) is None
print('PASS: completed receipt restores display only; pending, refunded, wrong totals, missing XP and mismatched IDs show no success.')
