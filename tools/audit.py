import plistlib, os, sys

root = r'E:\222\TKFloatKey'
problems = []
VAR = chr(36) + '('

def check_plist(path, label):
    if not os.path.exists(path):
        problems.append(label + ': missing file')
        return None
    try:
        d = plistlib.load(open(path, 'rb'))
    except Exception as e:
        problems.append(label + ': plist parse failed ' + str(e))
        return None
    required = ['CFBundleIdentifier', 'CFBundleExecutable', 'CFBundleName',
                'CFBundleVersion', 'CFBundleShortVersionString', 'CFBundlePackageType']
    print('--- ' + label + ' ---')
    for k in required:
        v = d.get(k)
        if v in (None, ''):
            problems.append(label + ': missing ' + k)
        elif isinstance(v, str) and VAR in v:
            problems.append(label + ': unexpanded variable in ' + k + ' -> ' + v)
        print('   %-28s = %s' % (k, v))
    ext = d.get('NSExtension')
    print('   %-28s = %s' % ('NSExtension', 'present' if ext else 'absent'))
    return d

main = check_plist(os.path.join(root, 'TKFloatKey', 'Info.plist'), 'MainApp')
kb = check_plist(os.path.join(root, 'TKFloatKeyKeyboard', 'Info.plist'), 'Keyboard')

if main and kb:
    mi = main.get('CFBundleIdentifier', '')
    ki = kb.get('CFBundleIdentifier', '')
    if not ki.startswith(mi + '.'):
        problems.append('keyboard id ' + ki + ' not prefixed by main id ' + mi)
    else:
        print()
        print('prefix check OK: ' + ki + ' starts with ' + mi + '.')
    if not kb.get('NSExtension'):
        problems.append('keyboard Info.plist has no NSExtension')
    pc = kb.get('NSExtensionPrincipalClass', '')
    if VAR in pc:
        problems.append('NSExtensionPrincipalClass uses variable -> ' + pc)

# check pbxproj bundle ids
pbx = open(os.path.join(root, 'TKFloatKey.xcodeproj', 'project.pbxproj'), encoding='utf-8').read()
ids = sorted(set(part.split('=')[1].strip().rstrip(';')
                 for part in pbx.split('PRODUCT_BUNDLE_IDENTIFIER')[1:]))
print()
print('pbxproj PRODUCT_BUNDLE_IDENTIFIER: ' + str(ids))

# swift syntax brace balance
for dirpath, _, files in os.walk(root):
    for f in files:
        if f.endswith('.swift'):
            p = os.path.join(dirpath, f)
            t = open(p, encoding='utf-8').read()
            if t.count('{') != t.count('}'):
                problems.append('brace mismatch in ' + f)
            # naive: detect string literal spanning raw newline outside """)
            if '"""' in t:
                pass

print()
if problems:
    print('=== PROBLEMS ===')
    for p in problems:
        print(' x ' + p)
else:
    print('=== ALL CHECKS PASSED ===')
