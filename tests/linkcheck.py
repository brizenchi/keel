import os, re, sys, unicodedata
root = sys.argv[1]
files = []
for base in sys.argv[2:]:
    p = os.path.join(root, base)
    if os.path.isfile(p): files.append(p)
    else:
        for d, _, fs in os.walk(p):
            if 'node_modules' in d or '/.cache' in d: continue
            files += [os.path.join(d, f) for f in fs if f.endswith('.md')]
def slug(h):
    h = h.strip().lower()
    h = re.sub(r'[`*_~]', '', h)
    out = []
    for ch in h:
        if ch == ' ': out.append('-')
        elif ch == '-' : out.append('-')
        elif ch.isalnum() or unicodedata.category(ch).startswith('L'): out.append(ch)
    return ''.join(out)
def anchors(path):
    s = open(path, encoding='utf-8').read()
    s = re.sub(r'```.*?```', '', s, flags=re.S)
    return {slug(m.group(2)) for m in re.finditer(r'^(#{1,6})\s+(.*)$', s, re.M)}
bad = 0
for f in files:
    text = open(f, encoding='utf-8').read()
    text_nocode = re.sub(r'```.*?```', '', text, flags=re.S)
    for m in re.finditer(r'\]\(([^)\s]+)\)', text_nocode):
        link = m.group(1)
        if re.match(r'^[a-z]+://', link) or link.startswith('mailto:'): continue
        path, _, anchor = link.partition('#')
        target = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
        if not os.path.exists(target):
            print(f'MISSING FILE  {os.path.relpath(f, root)} -> {link}'); bad += 1; continue
        if anchor and target.endswith('.md') and anchor not in anchors(target):
            print(f'MISSING ANCHOR {os.path.relpath(f, root)} -> {link}'); bad += 1
print(f"{len(files)} files checked, {bad} broken links")
sys.exit(1 if bad else 0)
