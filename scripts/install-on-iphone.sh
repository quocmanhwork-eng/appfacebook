#!/bin/bash
# Build và cài DuoSocial lên iPhone đang cắm vào máy Mac.
#
# Yêu cầu: macOS + Xcode 16 trở lên, đã đăng nhập Apple ID trong Xcode (Settings > Accounts),
#          iPhone chạy iOS 17+ cắm cáp vào Mac, đã mở khóa và chọn "Tin cậy máy tính này".
#
# Cách chạy (trong thư mục repo):
#     ./scripts/install-on-iphone.sh
#
# Tùy chọn qua biến môi trường:
#     TEAM_ID=ABCDE12345      Team ID của Apple ID (mặc định: tự dò từ Xcode)
#     BUNDLE_ID=com.ten.app   Bundle ID (mặc định: com.<tên-user-mac>.duosocial)
#     DEVICE=<udid|tên máy>   Chọn iPhone khi cắm nhiều máy
set -euo pipefail

cd "$(dirname "$0")/.."

step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31m✖ %s\033[0m\n' "$1" >&2; exit 1; }

# --- 1. Kiểm tra Xcode -------------------------------------------------------
step "Kiểm tra Xcode"
command -v xcodebuild >/dev/null 2>&1 || fail "Chưa có Xcode. Cài Xcode từ App Store rồi mở Xcode một lần."
if ! xcode-select -p 2>/dev/null | grep -q "Xcode"; then
    fail "Đang dùng Command Line Tools thay vì Xcode. Chạy: sudo xcode-select -s /Applications/Xcode.app"
fi
XCODE_MAJOR=$(xcodebuild -version | awk 'NR==1 { split($2, v, "."); print v[1] }')
[ "${XCODE_MAJOR:-0}" -ge 16 ] || fail "Cần Xcode 16 trở lên (đang có $(xcodebuild -version | head -1))."
xcodebuild -version | head -1

if ! xcodebuild -showsdks 2>/dev/null | grep -q "iphoneos"; then
    step "Tải thành phần iOS cho Xcode (chỉ lần đầu, có thể mất vài phút)"
    xcodebuild -downloadPlatform iOS
fi

# --- 2. Team ID (Apple ID dùng để ký app) ------------------------------------
step "Tìm Team ID"
detect_team_id() {
    local id
    for key in IDEProvisioningTeamByIdentifier IDEProvisioningTeams; do
        id=$(defaults read com.apple.dt.Xcode "$key" 2>/dev/null |
            grep -Eo 'teamID = "?[A-Z0-9]{10}"?' | grep -Eo '[A-Z0-9]{10}' | head -1 || true)
        if [ -n "$id" ]; then echo "$id"; return; fi
    done
    security find-certificate -a -c "Apple Development" -p 2>/dev/null |
        openssl x509 -noout -subject 2>/dev/null |
        grep -Eo 'OU ?= ?[A-Z0-9]{10}' | grep -Eo '[A-Z0-9]{10}$' | head -1 || true
}
TEAM_ID="${TEAM_ID:-$(detect_team_id)}"
if [ -z "$TEAM_ID" ]; then
    cat <<'EOF'
Không tìm thấy Apple ID trong Xcode.
  1. Mở Xcode > Settings… (⌘,) > Accounts > bấm "+" > Apple ID và đăng nhập.
  2. Chạy lại script này.
Hoặc nhập Team ID (10 ký tự, xem ở Xcode > Settings > Accounts > chọn team):
EOF
    read -r -p "Team ID: " TEAM_ID
fi
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "Team ID không hợp lệ: '$TEAM_ID'"
echo "Team ID: $TEAM_ID"

# --- 3. Bundle ID riêng (Apple không cho hai người dùng chung một ID) -------------
USER_SLUG=$(id -un | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
BUNDLE_ID="${BUNDLE_ID:-com.${USER_SLUG:-me}.duosocial}"
echo "Bundle ID: $BUNDLE_ID"

# --- 4. Tìm iPhone đang cắm ----------------------------------------------------
step "Tìm iPhone"
DEVICES_JSON=$(mktemp -t duosocial-devices)
trap 'rm -f "$DEVICES_JSON"' EXIT
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 ||
    fail "Không đọc được danh sách thiết bị (xcrun devicectl). Mở Xcode một lần rồi thử lại."

DEVICE_LINE=$(DEVICE_FILTER="${DEVICE:-}" /usr/bin/python3 - "$DEVICES_JSON" <<'PY'
import json, os, sys

wanted = os.environ.get("DEVICE_FILTER", "").strip().lower()
devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
candidates = []
for device in devices:
    hardware = device.get("hardwareProperties", {})
    props = device.get("deviceProperties", {})
    connection = device.get("connectionProperties", {})
    if hardware.get("platform") != "iOS":
        continue
    udid = hardware.get("udid", "")
    name = props.get("name", "iPhone")
    if wanted and wanted not in (udid.lower(), name.lower(), device.get("identifier", "").lower()):
        continue
    if connection.get("pairingState") not in (None, "paired"):
        continue
    wired = connection.get("transportType") == "wired"
    candidates.append((not wired, udid, name, props.get("osVersionNumber", "?")))
if not candidates:
    sys.exit(1)
_, udid, name, os_version = sorted(candidates)[0]
print(f"{udid}\t{name}\t{os_version}")
PY
) || fail "Không thấy iPhone nào. Cắm cáp, mở khóa iPhone, chọn \"Tin cậy máy tính này\" rồi chạy lại."

DEVICE_UDID=$(cut -f1 <<<"$DEVICE_LINE")
DEVICE_NAME=$(cut -f2 <<<"$DEVICE_LINE")
DEVICE_OS=$(cut -f3 <<<"$DEVICE_LINE")
echo "Thiết bị: $DEVICE_NAME (iOS $DEVICE_OS)"
DEVICE_OS_MAJOR="${DEVICE_OS%%.*}"
if [[ "$DEVICE_OS_MAJOR" =~ ^[0-9]+$ ]] && [ "$DEVICE_OS_MAJOR" -lt 17 ]; then
    fail "DuoSocial cần iOS 17 trở lên (máy đang chạy iOS $DEVICE_OS)."
fi

# --- 5. Build ------------------------------------------------------------------
step "Build DuoSocial (lần đầu mất vài phút)"
xcodebuild build \
    -project DuoSocial.xcodeproj \
    -scheme DuoSocial \
    -configuration Release \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath build \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_STYLE=Automatic \
    -quiet ||
    fail "Build thất bại. Xem lỗi phía trên (thường do chưa đăng nhập Apple ID trong Xcode hoặc Bundle ID bị trùng — thử BUNDLE_ID=com.tenkhac.duosocial)."

APP_PATH="build/Build/Products/Release-iphoneos/DuoSocial.app"
[ -d "$APP_PATH" ] || fail "Không tìm thấy $APP_PATH sau khi build."

# --- 6. Cài & mở -----------------------------------------------------------------
step "Cài lên $DEVICE_NAME"
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH" ||
    fail "Cài thất bại. Hãy bật Chế độ nhà phát triển trên iPhone (Cài đặt > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển), khởi động lại máy rồi chạy lại script."

step "Mở app"
if ! xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
    cat <<'EOF'
Đã cài xong nhưng iOS chưa cho mở app. Trên iPhone:
  1. Cài đặt > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển > Bật (máy sẽ khởi động lại).
  2. Cài đặt > Cài đặt chung > Quản lý VPN & thiết bị > chọn Apple ID của bạn > Tin cậy.
  3. Mở app DuoSocial trên màn hình chính.
EOF
    exit 0
fi

printf '\n\033[1;32m✔ Đã cài và mở DuoSocial trên %s.\033[0m\n' "$DEVICE_NAME"
cat <<'EOF'
Lưu ý: với Apple ID miễn phí, app chạy được 7 ngày. Hết hạn thì cắm máy và chạy lại script này
(giữ nguyên Bundle ID để không mất các tài khoản đã đăng nhập).
EOF
