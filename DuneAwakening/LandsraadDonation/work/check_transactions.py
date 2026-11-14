import pathlib,sys,tempfile,shutil
sys.path.insert(0,'work/lua-check')
from lupa.lua54 import LuaRuntime
source=pathlib.Path('work/LandsraadDonations').resolve()
harness=pathlib.Path('work/check_transactions.lua').read_text(encoding='utf-8')
cases=['success','cycle_change','no_receipt','payment_error','schedule_error','owner_change','balance_change','extra_progress','crash_after_debit','refund_error','not_ready','checkpoint_error','stale_receipt','complete_checkpoint_error']
cases+=['xp_success','xp_cap','xp_missing','xp_extra','xp_call_error','xp_external_change']
for mode in cases:
    with tempfile.TemporaryDirectory(dir=str(pathlib.Path('work').resolve())) as temp:
        path=pathlib.Path(temp)
        (path/'Scripts').mkdir()
        shutil.copyfile(source/'Scripts/transaction_guard.lua',path/'Scripts/transaction_guard.lua')
        runtime=LuaRuntime(unpack_returned_tuples=True)
        runtime.execute('print=function()end')
        assert runtime.execute(harness,temp.replace('\\','/'),str(source).replace('\\','/'),mode)
for content in ['123 begin','123 begin\n123 complete','garbage\n','123 begin\n124 complete\n','123 begin\n124 begin\n']:
    with tempfile.TemporaryDirectory(dir=str(pathlib.Path('work').resolve())) as temp:
        pathlib.Path(temp,'transaction-state.log').write_text(content,encoding='utf-8')
        runtime=LuaRuntime(unpack_returned_tuples=True)
        guard=runtime.execute('return dofile(...)',str(source/'Scripts/transaction_guard.lua').replace('\\','/'))
        try: guard['new'](temp.replace('\\','/'))
        except Exception: pass
        else: raise AssertionError('Corrupt checkpoint accepted: '+repr(content))
print('PASS: 20 offline transaction scenarios including XP + 5 corrupt checkpoints. No game actions or installed-file changes.')
