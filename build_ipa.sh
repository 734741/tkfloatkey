#!/bin/bash
# ============================================================
#  TKFloatKey —— 在 macOS 上一键编译 + 打包 IPA
#
#  用法:
#     bash build_ipa.sh <TEAM_ID>            只编译（未签名 IPA）
#     bash build_ipa.sh <TEAM_ID> --sign     用本机描述文件签名
#  例:
#     bash build_ipa.sh ABCDE12345
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="${1:-YOURTEAMID}"
SIGN_FLAG="${2:-}"

echo "==> 清理"
rm -rf build Payload TKFloatKey.ipa

echo "==> 编译 Release (iphoneos)"
if [ "$SIGN_FLAG" = "--sign" ]; then
  xcodebuild -project TKFloatKey.xcodeproj \
             -scheme TKFloatKey \
             -configuration Release \
             -sdk iphoneos \
             -derivedDataPath build \
             DEVELOPMENT_TEAM="$TEAM_ID" \
             -allowProvisioningUpdates \
             build
else
  xcodebuild -project TKFloatKey.xcodeproj \
             -scheme TKFloatKey \
             -configuration Release \
             -sdk iphoneos \
             -derivedDataPath build \
             CODE_SIGNING_ALLOWED=NO \
             CODE_SIGNING_REQUIRED=NO \
             CODE_SIGN_IDENTITY="" \
             DEVELOPMENT_TEAM="$TEAM_ID" \
             build
fi

APP="build/Build/Products/Release-iphoneos/TKFloatKey.app"
[ -d "$APP" ] || { echo "找不到 $APP"; exit 1; }

echo "==> 组装 Payload"
mkdir -p Payload
cp -R "$APP" Payload/

echo "==> 打包 ipa"
zip -qry TKFloatKey.ipa Payload
rm -rf Payload

echo "==> 完成: $(pwd)/TKFloatKey.ipa"
ls -lh TKFloatKey.ipa
