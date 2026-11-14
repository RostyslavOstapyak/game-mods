from pathlib import Path
import sys,shutil,tempfile,json
sys.path.insert(0,str(Path(__file__).resolve().parent/'skill-validation-deps'))
from lupa.lua54 import LuaRuntime
root=Path('work/LandsraadDonations');lua=LuaRuntime(unpack_returned_tuples=True)
L=lua.execute('return dofile(...)',str(root/'Scripts/localization.lua'))
read=lambda tag:lua.eval('function(tag)return function()return tag end end')(tag)
L.refresh(read('uk-UA'));assert L.code=='uk';assert L.t('ui.004')=='Як це працює'
L.refresh(read('en-US'));assert L.code=='en';assert L.t('ui.004')=='How it works'
assert L.message('Предмети списано.')=='Items removed.'
assert L.message('Пожертву підтверджено: 3 меланжу → 180 очок внеску.')=='Donation confirmed: 3 melange → 180 contribution points.'
assert L.message('Не вдалося прочитати журнал стану пожертв. Пожертви заблоковані до перевірки; меню доступне.').startswith('Could not read')
L.refresh(read('uk'));assert L.message('Processing donation...')=='Обробляємо пожертву…'
L.refresh(read('de-DE'));assert L.code=='en'
L.refresh(read('../../bad'));assert L.code=='en'
# Partial third-party pack and malformed file tested in an isolated copy only.
from contextlib import nullcontext
import uuid
with nullcontext(str(Path('work/localization-fixtures')/uuid.uuid4().hex))as directory:
 temp=Path(directory);(temp/'Scripts').mkdir(parents=True);shutil.copy2(root/'Scripts/localization.lua',temp/'Scripts/localization.lua');shutil.copytree(root/'Locales',temp/'Locales')
 (temp/'Locales/fr.tsv').write_text('ui.004\tAide\n',encoding='utf-8')
 other=LuaRuntime(unpack_returned_tuples=True);T=other.execute('return dofile(...)',str(temp/'Scripts/localization.lua'));reader=lambda tag:other.eval('function(tag)return function()return tag end end')(tag)
 T.refresh(reader('fr-CA'));assert T.code=='fr';assert T.t('ui.004')=='Aide';assert T.t('ui.014')=='All houses'
 (temp/'Locales/it.tsv').write_text('ui.004\tOne\nui.004\tTwo\n',encoding='utf-8');T.refresh(reader('it'));assert T.code=='en'
# Verify catalog parity and printf placeholders, and that every referenced key exists.
import re
packs={}
for code in ['source','en','uk']:
 pack={}
 for line in (root/'Locales'/(code+'.tsv')).read_text(encoding='utf-8').splitlines():
  if line and not line.startswith('#'):key,value=line.split('\t',1);assert key not in pack;pack[key]=value
 packs[code]=pack
assert packs['en'].keys()==packs['uk'].keys()==packs['source'].keys()
for key,value in packs['source'].items():
 for code in ['en','uk']:assert re.findall(r'%[ds]',value)==re.findall(r'%[ds]',packs[code][key]),(code,key)
for p in (root/'Scripts').glob('*.lua'):
 for key in re.findall(r"L\.t\('([^']+)'\)",p.read_text(encoding='utf-8-sig')):assert key in packs['en'],(p.name,key)
print('PASS '+str(len(packs['en']))+' keys: Ukrainian/English, region fallback, custom partial pack, malformed pack, backend messages, placeholders and reference coverage.')
