"""Check Markdown local links without executing source or project scripts."""
from pathlib import Path
from urllib.parse import urlsplit,unquote
import re
root=Path(__file__).resolve().parents[1]/'ineed-creator'
errors=[]
for p in root.rglob('*.md'):
 for ref in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  link=urlsplit(ref)
  if link.scheme or not link.path:continue
  target=(p.parent/unquote(link.path)).resolve()
  if not target.is_relative_to(root) or not target.exists():errors.append(f'{p.relative_to(root)}: {ref}')
if errors:raise SystemExit('\n'.join(errors))
print('Markdown local links: valid')
