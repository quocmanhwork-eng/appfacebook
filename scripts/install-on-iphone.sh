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
#     TEAM_ID=ABCDE12345      Team ID của Apple ID (mặc định: tự dò)
#     BUNDLE_ID=com.ten.app   Bundle ID (mặc định: com.duosocial.<team id>)
#     DEVICE=<udid|tên máy>   Chọn iPhone khi cắm nhiều máy
#
# Team ID và Bundle ID được nhớ trong .install-config để lần cài lại (sau 7 ngày) dùng đúng app cũ
# và không mất các tài khoản đã đăng nhập.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG_FILE=".install-config"

step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }
note() { printf '\033[0;33m%s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31m✖ %s\033[0m\n' "$1" >&2; exit 1; }
pause() { read -r -p "Làm xong thì quay lại đây và bấm Enter để tiếp tục… " _; }

# Giá trị đã lưu từ lần trước (biến môi trường vẫn được ưu tiên).
SAVED_TEAM_ID=""
SAVED_BUNDLE_ID=""
if [ -f "$CONFIG_FILE" ]; then
    SAVED_TEAM_ID=$(sed -n 's/^TEAM_ID=//p' "$CONFIG_FILE" | head -1)
    SAVED_BUNDLE_ID=$(sed -n 's/^BUNDLE_ID=//p' "$CONFIG_FILE" | head -1)
fi

# --- 1. Kiểm tra Xcode -------------------------------------------------------
step "Kiểm tra Xcode"
command -v xcodebuild >/dev/null 2>&1 || fail "Chưa có Xcode. Cài Xcode từ App Store rồi mở Xcode một lần."
if ! xcode-select -p 2>/dev/null | grep -q "Xcode"; then
    fail "Đang dùng Command Line Tools thay vì Xcode. Chạy: sudo xcode-select -s /Applications/Xcode.app"
fi
XCODE_VERSION=$(xcodebuild -version | head -1)
XCODE_MAJOR=$(awk '{ split($2, v, "."); print v[1] }' <<<"$XCODE_VERSION")
[ "${XCODE_MAJOR:-0}" -ge 16 ] || fail "Cần Xcode 16 trở lên (đang có $XCODE_VERSION)."
echo "$XCODE_VERSION"

SDKS=$(xcodebuild -showsdks 2>/dev/null || true)
if ! grep -q "iphoneos" <<<"$SDKS"; then
    step "Tải thành phần iOS cho Xcode (chỉ lần đầu, có thể mất vài phút)"
    xcodebuild -downloadPlatform iOS
fi

# --- 2. Team ID (Apple ID dùng để ký app) ------------------------------------
step "Tìm Team ID"
find_team() { /usr/bin/python3 scripts/find-team-id.py "$@"; }

TEAM_ID="${TEAM_ID:-$SAVED_TEAM_ID}"
if [ -n "$TEAM_ID" ]; then
    echo "Team ID: $TEAM_ID"
else
    TEAM_LINE=$(find_team 2>/dev/null | head -1 || true)
    if [ -z "$TEAM_LINE" ]; then
        cat <<'EOF'
Xcode chưa lưu Team ID ở chỗ script đọc được (thường gặp khi vừa thêm Apple ID).
Script sẽ mở dự án trong Xcode — bạn chỉ cần chọn Team một lần:
  1. Cột bên trái: bấm "DuoSocial" (biểu tượng màu xanh trên cùng).
  2. Ở giữa, mục TARGETS chọn "DuoSocial" → bấm tab "Signing & Capabilities".
  3. Ô "Team": chọn tên bạn, dạng "Tên Bạn (Personal Team)".
     Nếu bên dưới hiện dòng báo lỗi màu đỏ thì cứ bỏ qua — script sẽ tự xử lý.
EOF
        open DuoSocial.xcodeproj
        pause
        TEAM_LINE=$(find_team 2>/dev/null | head -1 || true)
    fi
    if [ -z "$TEAM_LINE" ]; then
        echo
        note "Thông tin gỡ lỗi (hãy gửi đoạn này nếu cần hỗ trợ):"
        find_team --diagnose || true
        fail "Vẫn chưa tìm thấy Team ID. Kiểm tra Xcode > Settings… > Accounts đã có Apple ID và mục Team hiện \"(Personal Team)\", rồi chạy lại. Hoặc chạy: TEAM_ID=<mã 10 ký tự> ./scripts/install-on-iphone.sh"
    fi
    TEAM_ID=$(cut -f1 <<<"$TEAM_LINE")
    echo "Team: $(cut -f2 <<<"$TEAM_LINE") [$TEAM_ID] — lấy từ $(cut -f3 <<<"$TEAM_LINE")"
fi
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "Team ID không hợp lệ: '$TEAM_ID' (phải gồm 10 chữ in hoa/số)."

# --- 3. Bundle ID riêng (Apple không cho hai người dùng chung một ID) -------------
TEAM_SLUG=$(tr '[:upper:]' '[:lower:]' <<<"$TEAM_ID")
BUNDLE_ID="${BUNDLE_ID:-${SAVED_BUNDLE_ID:-com.duosocial.$TEAM_SLUG}}"
echo "Bundle ID: $BUNDLE_ID"
printf 'TEAM_ID=%s\nBUNDLE_ID=%s\n' "$TEAM_ID" "$BUNDLE_ID" >"$CONFIG_FILE"

# --- 4. Tìm iPhone đang cắm ----------------------------------------------------
step "Tìm iPhone"
DEVICES_JSON=$(mktemp -t duosocial-devices)
trap 'rm -f "$DEVICES_JSON"' EXIT

# In: udid<TAB>tên<TAB>phiên bản iOS<TAB>trạng thái Developer Mode. Không thấy: in danh sách thiết bị ra stderr.
detect_device() {
    xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 ||
        fail "Không đọc được danh sách thiết bị (xcrun devicectl). Mở Xcode một lần rồi thử lại."
    DEVICE_FILTER="${DEVICE:-}" /usr/bin/python3 - "$DEVICES_JSON" <<'PY'
import json, os, sys

wanted = os.environ.get("DEVICE_FILTER", "").strip().lower()
devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
candidates, seen = [], []
for device in devices:
    hardware = device.get("hardwareProperties", {})
    props = device.get("deviceProperties", {})
    connection = device.get("connectionProperties", {})
    udid = hardware.get("udid", "")
    name = props.get("name", "?")
    pairing = connection.get("pairingState", "?")
    seen.append(f"  - {name} ({hardware.get('platform', '?')}, ghép đôi: {pairing}, kết nối: {connection.get('transportType', '?')})")
    if hardware.get("platform") != "iOS":
        continue
    if wanted and wanted not in (udid.lower(), name.lower(), device.get("identifier", "").lower()):
        continue
    if pairing not in (None, "paired"):
        continue
    wired = connection.get("transportType") == "wired"
    candidates.append((not wired, udid, name, props.get("osVersionNumber", "?"), props.get("developerModeStatus", "unknown")))
if not candidates:
    print("Các thiết bị Xcode đang thấy:", file=sys.stderr)
    print("\n".join(seen) or "  (không có)", file=sys.stderr)
    sys.exit(1)
print("\t".join(sorted(candidates)[0][1:]))
PY
}

DEVICE_LINE=$(detect_device) ||
    fail "Không thấy iPhone nào. Cắm cáp, mở khóa iPhone, chọn \"Tin cậy máy tính này\" rồi chạy lại. Nếu iPhone hiện \"ghép đôi: unpaired\" ở trên, rút cáp cắm lại và chọn Tin cậy."

DEVICE_UDID=$(cut -f1 <<<"$DEVICE_LINE")
DEVICE_NAME=$(cut -f2 <<<"$DEVICE_LINE")
DEVICE_OS=$(cut -f3 <<<"$DEVICE_LINE")
DEVELOPER_MODE=$(cut -f4 <<<"$DEVICE_LINE")
echo "Thiết bị: $DEVICE_NAME (iOS $DEVICE_OS)"
DEVICE_OS_MAJOR="${DEVICE_OS%%.*}"
if [[ "$DEVICE_OS_MAJOR" =~ ^[0-9]+$ ]] && [ "$DEVICE_OS_MAJOR" -lt 17 ]; then
    fail "DuoSocial cần iOS 17 trở lên (máy đang chạy iOS $DEVICE_OS)."
fi

# Khi Developer Mode tắt, Xcode không cho build/cài lên iPhone.
if [ "$DEVELOPER_MODE" = "disabled" ]; then
    cat <<'EOF'

Cần bật Chế độ nhà phát triển trên iPhone:
  1. Cài đặt > Quyền riêng tư & Bảo mật > kéo xuống cuối > Chế độ nhà phát triển > Bật.
  2. iPhone khởi động lại; mở khóa và bấm "Bật" khi được hỏi.
  Nếu chưa thấy mục này: giữ iPhone cắm vào Mac, trong Xcode chọn Window > Devices and Simulators,
  đợi vài giây rồi xem lại trong Cài đặt.
EOF
    pause
    DEVICE_LINE=$(detect_device) || fail "Không thấy iPhone sau khi khởi động lại. Mở khóa iPhone rồi chạy lại script."
    DEVICE_UDID=$(cut -f1 <<<"$DEVICE_LINE")
    DEVELOPER_MODE=$(cut -f4 <<<"$DEVICE_LINE")
    [ "$DEVELOPER_MODE" != "disabled" ] || fail "Chế độ nhà phát triển vẫn đang tắt. Bật xong thì chạy lại script."
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
    fail "Build thất bại. Xem lỗi phía trên. Nếu báo Bundle ID đã bị dùng, chạy lại với: BUNDLE_ID=com.tenkhac.duosocial ./scripts/install-on-iphone.sh"

APP_PATH="build/Build/Products/Release-iphoneos/DuoSocial.app"
[ -d "$APP_PATH" ] || fail "Không tìm thấy $APP_PATH sau khi build."

# --- 6. Cài & mở -----------------------------------------------------------------
step "Cài lên $DEVICE_NAME"
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH" ||
    fail "Cài thất bại. Kiểm tra Chế độ nhà phát triển đã bật (Cài đặt > Quyền riêng tư & Bảo mật), mở khóa iPhone rồi chạy lại script."

step "Mở app"
if ! xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
    cat <<'EOF'
Đã cài xong nhưng iOS chưa cho mở app. Trên iPhone:
  1. Cài đặt > Cài đặt chung > Quản lý VPN & thiết bị > chọn Apple ID của bạn > Tin cậy.
  2. Mở app DuoSocial trên màn hình chính.
EOF
    exit 0
fi

printf '\n\033[1;32m✔ Đã cài và mở DuoSocial trên %s.\033[0m\n' "$DEVICE_NAME"
cat <<'EOF'
Lưu ý: với Apple ID miễn phí, app chạy được 7 ngày. Hết hạn thì cắm máy và chạy lại script này
(script nhớ Bundle ID nên các tài khoản đã đăng nhập vẫn còn).
EOF
