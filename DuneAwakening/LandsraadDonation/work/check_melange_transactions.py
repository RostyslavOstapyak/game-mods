import pathlib,sys,tempfile,shutil
sys.path.insert(0,'work/lua-check')
from lupa.lua54 import LuaRuntime
source=pathlib.Path('work/LandsraadDonations').resolve()
harness=pathlib.Path('work/check_melange_transactions.lua').read_text(encoding='utf-8')
cases=['success','delayed_receipt','insufficient','loading','no_removal','partial','call_error','false_return','cycle_change','pawn_change','no_receipt']
for mode in cases:
 with tempfile.TemporaryDirectory(dir='work')as temp:
  target=pathlib.Path(temp).resolve();(target/'Scripts').mkdir()
  shutil.copyfile(source/'Scripts/transaction_guard.lua',target/'Scripts/transaction_guard.lua')
  lua=LuaRuntime(unpack_returned_tuples=True);lua.execute('print=function()end')
  assert lua.execute(harness,str(target).replace('\\','/'),str(source).replace('\\','/'),mode),mode
print('PASS: 11 Melange transaction scenarios including delayed receipt; whole-item debit, verified count, no bank change and persistent failure lock.')
