"""Full pre-build audit: catches everything that would make the IPA wrong
or make xcodebuild fail, before the user spends another build cycle."""
import os, re, plistlib, sys

ROOT = r'E:\222\TKFloatKey'
PBX = os.path.join(ROOT, 'TKFloatKey.xcodeproj', 'project.pbxproj')
problems = []
info = []

def ok(msg):  info.append('  OK   ' + msg)
def bad(msg): problems.append('  FAIL ' + msg)

# ---------------------------------------------------------------- Swift sources
app_dir = os.path.join(ROOT, 'TKFloatKey')
kb_dir = os.path.join(ROOT, 'TKFloatKeyKeyboard')

swift_all = []
for dp, _, fs in os.walk(ROOT):
    if 'build' in dp.split(os.sep):
        continue
    for f in fs:
        if f.endswith('.swift'):
            swift_all.append(os.path.join(dp, f))

# app target sources = files under TKFloatKey/ + Shared/
app_sources = sorted([p for p in swift_all
                      if os.sep + 'TKFloatKey' + os.sep in p or os.sep + 'Shared' + os.sep in p])
kb_sources  = sorted([p for p in swift_all if os.sep + 'TKFloatKeyKeyboard' + os.sep in p])

info.append('\n== 主 App 源文件 ==')
for p in app_sources:
    info.append('  ' + os.path.relpath(p, ROOT))

info.append('\n== 键盘扩展源文件 ==')
for p in kb_sources:
    info.append('  ' + os.path.relpath(p, ROOT))

# ---------------------------------------------------------------- brace balance
info.append('\n== 括号平衡 ==')
for p in swift_all:
    t = open(p, encoding='utf-8').read()
    name = os.path.basename(p)
    if t.count('{') != t.count('}'):
        bad('%s 花括号不平衡 %d/%d' % (name, t.count('{'), t.count('}')))
    else:
        ok('%s' % name)

# ---------------------------------------------------------------- undefined helpers
info.append('\n== 调用了但没定义的私有方法 ==')
all_text = ''
for p in swift_all:
    all_text += open(p, encoding='utf-8').read() + '\n'

# collect every func name defined anywhere
defined = set(re.findall(r'func\s+(\w+)', all_text))
# collect private helper calls of the form  name(  that are not system APIs
helpers = set(re.findall(r'(?<![\w.])(flash|copy|masked|smallButton|quickButton|fieldRow|totpRow|apply|reload|persist|renumber|addSlot|append|delete|deleteMultiple|clearAll|republishToChannel|pushToChannel|shortLabel)\s*\(', all_text))
for h in sorted(helpers):
    if h not in defined:
        bad('调用了 %s() 但没定义' % h)
    else:
        ok('%s() 已定义' % h)

# ---------------------------------------------------------------- Info.plist
info.append('\n== Info.plist ==')
REQ_APP = ['CFBundleIdentifier','CFBundleExecutable','CFBundleName','CFBundleVersion',
           'CFBundleShortVersionString','CFBundlePackageType']
REQ_KB  = REQ_APP + ['NSExtension']
try:
    main = plistlib.load(open(os.path.join(app_dir,'Info.plist'),'rb'))
    for k in REQ_APP:
        v = main.get(k)
        if v in (None,''): bad('主App 缺 %s' % k)
        elif isinstance(v,str) and '$(' in v: bad('主App %s 含未展开变量 %s' % (k,v))
        else: ok('主App %s=%s' % (k,v))
except Exception as e:
    bad('主App Info.plist 读取失败 %s' % e)

# ---------------------------------------------------------------- project build phases
info.append('\n== 工程的编译清单 ==')
pbx = open(PBX, encoding='utf-8').read()
m = re.search(r'/\* Sources \*/ = \{.*?files = \((.*?)\);', pbx, re.S)
listed = re.findall(r'/\* (\S+\.swift) in Sources', m.group(1)) if m else []
info.append('  Sources 阶段文件: ' + ', '.join(dict.fromkeys(listed)))

for p in app_sources:
    name = os.path.basename(p)
    if name not in listed:
        bad('%s 在磁盘上但没加入 Sources 编译阶段' % name)

# check each listed file actually exists
for name in dict.fromkeys(listed):
    found = any(os.path.basename(p) == name for p in swift_all)
    if not found:
        bad('Sources 里列了 %s 但磁盘上没有这个文件' % name)

# ---------------------------------------------------------------- duplicate func names in same type
info.append('\n== 同文件重复定义 ==')
for p in swift_all:
    t = open(p, encoding='utf-8').read()
    names = re.findall(r'func\s+(\w+)\s*[(<]', t)
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        bad('%s 重复定义 %s' % (os.path.basename(p), ', '.join(dup)))
    else:
        ok('%s 无重复' % os.path.basename(p))

# ---------------------------------------------------------------- output
print('\n'.join(info))
print('\n== 结论 ==')
if problems:
    print('\n'.join(problems))
    print('\n共 %d 个问题' % len(problems))
    sys.exit(1)
else:
    print('  全部通过，可以编译')
