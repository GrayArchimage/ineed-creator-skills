"""Fail docs checks when the platform format/limit contract changes."""
from pathlib import Path
import re,json,sys
root=Path(__file__).resolve().parents[1]
platform=Path(sys.argv[1])
policy=json.loads((root/'ineed-creator/guides/packaging/policy.json').read_text())
s=(platform/'lib/static-site-package.ts').read_text()
block=s.split('const allowedExtensions = new Set([')[1].split(']);',1)[0]
actual=set(re.findall(r'"(\.[a-z0-9]+)"',block))
assert actual==set(policy['allowedExtensions']), 'Format whitelist drift: review platform contract before release'
# Verify against the published constants; never execute the platform config.
limits=(platform/'lib/static-site-upload-limits.ts').read_text()
for text in ['MAX_STATIC_FILES = 500','MAX_STATIC_TOTAL_BYTES = 50 * 1024 * 1024','MAX_STATIC_FILE_BYTES = 50 * 1024 * 1024']:assert text in limits,text
assert 'GODOT_EXPANDED_LIMIT = 128 * 1024 * 1024' in (platform/'lib/godot-web-policy.ts').read_text()
formats=(root/'ineed-creator/guides/packaging/formats.md').read_text()
for ext in actual:assert ext in formats,ext
print('Published format and size contract matches creator documentation')
