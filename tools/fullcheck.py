import plistlib, os, sys, zipfile, subprocess, json

ROOT = r'E:\222\TKFloatKey'
IPA = r'C:\Users\Administrator\Downloads\ToDesk\TKFloatKey.ipa'
problems = []
warns = []

def sep(t):
    print('\n=== %s ===' % t)

# ---------------------------------------------------------------- 1. Info.plist
sep('1. Info.plist 完整性')
def load(p):
    return plistlib.load(open(p, 'rb'))

main_p = os.path.join(ROOT, 'TKFloatKey', 'Info.plist')
kb_p = os.path.join(ROOT, 'TKFloatKeyKeyboard', 'Info.plist')
main = load(main_p)
kb = load(kb_p)

REQ = ['CFBundleIdentifier', 'CFBundleExecutable', 'CFBundleName',
       'CFBundleVersion', 'CFBundleShortVersionString', 'CFBundlePackageType']

for label, d in (('MainApp', main), ('Keyboard', kb)):
    for k in REQ:
        v = d.get(k)
        if v in (None, ''):
            problems.append('%s missing %s' % (label, k))

        print('  %-9s %-28s = %s' % (label, k, v))

mi = main.get('CFBundleIdentifier', '')
ki = kb.get('CFBundleIdentifier', '')
print('  prefix: %s' % ('OK' if ki.startswith(mi + '.') else 'FAIL'))

# ---------------------------------------------------------------- 2. Swift syntax
sep('2. Swift 源码语法')
import re
swift_files = []
for dirpath, _, files in os.walk(ROOT):
    if '/build/' in dirpath.replace('\\', '/') or dirpath.endswith('\\build'):
        continue
    for f in files:
        if f.endswith('.swift'):
            swift_files.append(os.path.join(dirpath, f))

for p in swift_files:
    t = open(p, encoding='utf-8').read()
    name = os.path.basename(p)
    if t.count('{') != t.count('}'):
        problems.append('%s: brace mismatch %d/%d' % (name, t.count('{'), t.count('}')))

    # 检测普通引号字符串里出现裸换行（会编译失败）
    lines = t.split('\n')
    in_multiline = False
    for i, line in enumerate(lines):
        if line.count('"""') % 2 == 1:
            in_multiline = not in_multiline
            continue
        if in_multiline:
            continue
        if line.count('"') % 2 == 1 and not line.strip().startswith('//'):
            # 单行引号不配对，可能跨行了
            nxt = lines[i+1] if i+1 < len(lines) else ''
            if '"' not in nxt and not line.rstrip().endswith(','):
                problems.append('%s:%d unterminated string literal -> %s' % (name, i+1, line.strip()[:50]))
print('  扫描 %d 个 swift 文件' % len(swift_files))

# ---------------------------------------------------------------- 3. IPA 结构
sep('3. IPA 结构')
if os.path.exists(IPA):
    z = zipfile.ZipFile(IPA)
    names = z.namelist()
    has_main = any(n == 'Payload/TKFloatKey.app/' for n in names)
    kbexe = [n for n in names if 'PlugIns/TKFloatKeyKeyboard.appex/' in n and n.endswith('Info.plist')]
    print('  主App: %s' % ('OK' if has_main else 'MISSING'))
    print('  键盘Info.plist: %s' % ('OK' if kbexe else 'MISSING'))
    if kbexe:
        import tempfile, shutil
        tmp = tempfile.mkdtemp()
        z.extract(kbexe[0], tmp)
        d = plistlib.load(open(os.path.join(tmp, kbexe[0]), 'rb'))
        print('  IPA内键盘ID = %s' % d.get('CFBundleIdentifier'))
        print('  IPA内键盘可执行 = %s' % d.get('CFBundleExecutable'))
        shutil.rmtree(tmp, ignore_errors=True)
    z.close()
else:
    problems.append('IPA not found at %s' % IPA)

# ---------------------------------------------------------------- 4. 设备实际安装
sep('4. 设备上实际安装的 App')
py = r'C:\Users\Administrator\AppData\Local\Programs\Python\Python313\python.exe'
try:
    out = subprocess.run([py, '-m', 'pymobiledevice3', 'apps', 'list'],
                         capture_output=True, text=True, timeout=90,
                         encoding='utf-8', errors='replace').stdout
    ids = sorted(set(re.findall(r'"(com\.local\.tkfloatkey[^"]*)"', out)))
    print('  设备上的 tkfloatkey 相关 ID:')
    for i in ids:
        print('    ' + i)
    if not any('keyboard' in i for i in ids):
        problems.append('键盘扩展未注册到系统（Bundle ID 不匹配）')
except Exception as e:
    warns.append('无法查询设备: %s' % e)

# ---------------------------------------------------------------- 汇总
sep('结果')
if problems:
    for p in problems:
        print('  [X] ' + p)
else:
    print('  [OK] 全部通过')
for w in warns:
    print('  [!] ' + w)


