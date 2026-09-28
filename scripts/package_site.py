"""Archive the generated static site with deterministic bytes."""
from pathlib import Path
import zipfile,hashlib,json
root=Path(__file__).resolve().parents[1];site=root/'site';out=root/'dist/ineed-creator-site.zip'
with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in sorted(site.rglob('*')):
  if not p.is_file():continue
  info=zipfile.ZipInfo('creator-skills/'+p.relative_to(site).as_posix(),(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
  z.writestr(info,p.read_bytes(),compresslevel=9)
digest=hashlib.sha256(out.read_bytes()).hexdigest()
(root/'dist/site-manifest.json').write_text(json.dumps({'version':json.loads((site/'build-manifest.json').read_text())['version'],'file':out.name,'size':out.stat().st_size,'sha256':digest},indent=2)+'\n')
sums=root/'dist/SHA256SUMS';base='\n'.join(x for x in sums.read_text().splitlines() if not x.endswith('  '+out.name));sums.write_text(base+'\n'+digest+'  '+out.name+'\n')
print('Static site ZIP:',out.stat().st_size,'bytes',digest)
