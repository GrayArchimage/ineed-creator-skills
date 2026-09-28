"""Copy a verified static build and the same release Skill into the platform."""
from pathlib import Path
import sys,json,hashlib,shutil
root=Path(__file__).resolve().parents[1];platform=Path(sys.argv[1]).resolve()
assert (platform/'lib/static-site-package.ts').exists(),'Expected iNeed platform repository'
manifest=json.loads((root/'site/build-manifest.json').read_text())
for name,digest in manifest['files'].items():assert hashlib.sha256((root/'site'/name).read_bytes()).hexdigest()==digest,name
full=json.loads((root/'dist/manifest.json').read_text())
assert full==manifest['skill'];assert hashlib.sha256((root/'dist'/full['file']).read_bytes()).hexdigest()==full['sha256']
target=platform/'public/creator-skills';target.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'site',target,dirs_exist_ok=True)
# Site checksums cover its own two downloadable manifests; top-level Release
# checksums additionally cover the static-site archive, avoiding self-reference.
data=platform/'data/creator-skills';data.mkdir(parents=True,exist_ok=True)
for name in ['ineed-creator.zip','manifest.json','SHA256SUMS']:shutil.copyfile(root/'dist'/name,data/name)
print('Vendored creator library and Skill',full['version'],'into',platform)
