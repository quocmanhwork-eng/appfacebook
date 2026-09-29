#!/usr/bin/env python3
"""Tìm Team ID (của Apple ID dùng để ký app) trên máy Mac.

In ra mỗi dòng một team:  TEAM_ID<TAB>tên team<TAB>nguồn   (dòng đầu là lựa chọn tốt nhất).
Thoát mã 1 nếu không tìm thấy. Thêm --diagnose để in thông tin gỡ lỗi.

Các nơi được tìm, theo thứ tự ưu tiên:
  1. Team đã chọn trong dự án (Xcode > Signing & Capabilities > Team)
  2. Danh sách team trong cài đặt Xcode (Settings > Accounts)
  3. Chứng chỉ "Apple Development" trong Keychain
  4. Provisioning profile Xcode đã tải về
"""
import glob
import os
import plistlib
import re
import subprocess
import sys

TEAM_ID = re.compile(r"^[A-Z0-9]{10}$")
PROJECT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "DuoSocial.xcodeproj", "project.pbxproj")
PROFILE_DIRS = [
    "~/Library/Developer/Xcode/UserData/Provisioning Profiles",
    "~/Library/MobileDevice/Provisioning Profiles",
]
CERTIFICATE_NAMES = ["Apple Development", "iPhone Developer"]

RANK_PROJECT, RANK_XCODE_PAID, RANK_XCODE_FREE, RANK_XCODE_LAST, RANK_CERT, RANK_PROFILE = range(6)


def run(cmd, stdin=None):
    try:
        return subprocess.run(cmd, input=stdin, capture_output=True, check=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return None


def as_team_ids(value):
    values = value if isinstance(value, list) else [value]
    return [v for v in values if isinstance(v, str) and TEAM_ID.match(v)]


def teams_from_plist(node):
    """Tìm mọi mục có khóa teamID/TeamIdentifier ở bất kỳ độ sâu nào — Xcode đổi tên khóa cha giữa các phiên bản."""
    found = []
    if isinstance(node, dict):
        keys = {k.lower(): k for k in node if isinstance(k, str)}
        for id_key in ("teamid", "teamidentifier"):
            if id_key in keys:
                name = node.get(keys.get("teamname", ""), "") or node.get(keys.get("name", ""), "")
                is_free = bool(node.get(keys.get("isfreeprovisioningteam", ""), False))
                rank = RANK_XCODE_FREE if is_free else RANK_XCODE_PAID
                for team_id in as_team_ids(node[keys[id_key]]):
                    found.append((rank, team_id, name if isinstance(name, str) else ""))
        for key, value in node.items():
            if isinstance(key, str) and key.lower().endswith("selectedteamid"):
                found.extend((RANK_XCODE_LAST, team_id, "") for team_id in as_team_ids(value))
            else:
                found.extend(teams_from_plist(value))
    elif isinstance(node, list):
        for value in node:
            found.extend(teams_from_plist(value))
    return found


def teams_from_project(text):
    return [(RANK_PROJECT, team_id, "") for team_id in re.findall(r'DEVELOPMENT_TEAM = "?([A-Z0-9]{10})"?;', text)]


def team_from_certificate_subject(subject):
    team = re.search(r"OU ?= ?([A-Z0-9]{10})\b", subject)
    if not team:
        return None
    name = re.search(r"CN ?= ?(?:Apple Development|iPhone Developer): ([^/,(]+)", subject)
    return (RANK_CERT, team.group(1), name.group(1).strip() if name else "")


def xcode_preferences():
    data = run(["defaults", "export", "com.apple.dt.Xcode", "-"])
    try:
        return plistlib.loads(data) if data else {}
    except Exception:
        return {}


def certificate_teams():
    found = []
    for name in CERTIFICATE_NAMES:
        pem = (run(["security", "find-certificate", "-a", "-c", name, "-p"]) or b"").decode(errors="ignore")
        for block in re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.S):
            subject = (run(["openssl", "x509", "-noout", "-subject"], stdin=block.encode()) or b"").decode(errors="ignore")
            team = team_from_certificate_subject(subject)
            if team:
                found.append(team)
    return found


def profile_teams():
    found = []
    for directory in PROFILE_DIRS:
        for path in glob.glob(os.path.join(os.path.expanduser(directory), "*.*provision*")):
            data = run(["security", "cms", "-D", "-i", path])
            try:
                profile = plistlib.loads(data) if data else {}
            except Exception:
                continue
            name = profile.get("TeamName", "")
            found.extend((RANK_PROFILE, team_id, name) for team_id in as_team_ids(profile.get("TeamIdentifier", [])))
    return found


def best_teams(candidates):
    """Bỏ trùng, giữ nguồn tốt nhất và tên dễ hiểu nhất cho mỗi team."""
    best = {}
    for rank, team_id, name in candidates:
        current = best.get(team_id)
        if current is None or rank < current[0]:
            best[team_id] = (rank, team_id, name or (current[2] if current else ""))
        elif name and not current[2]:
            best[team_id] = (current[0], team_id, name)
    return sorted(best.values())


SOURCES = {
    RANK_PROJECT: "dự án Xcode",
    RANK_XCODE_PAID: "tài khoản Xcode",
    RANK_XCODE_FREE: "tài khoản Xcode (Personal Team)",
    RANK_XCODE_LAST: "team chọn gần nhất trong Xcode",
    RANK_CERT: "chứng chỉ Apple Development",
    RANK_PROFILE: "provisioning profile",
}


def diagnose(preferences):
    print("--- Chẩn đoán Team ID ---", file=sys.stderr)
    keys = sorted(k for k in preferences if re.search(r"team|account|appleid", k, re.I))
    print(f"Khóa liên quan trong cài đặt Xcode: {', '.join(keys) or '(không có)'}", file=sys.stderr)
    accounts = [k for k in preferences if "account" in k.lower()]
    for key in accounts:
        value = preferences[key]
        size = len(value) if isinstance(value, (list, dict)) else 1
        print(f"  {key}: {type(value).__name__} ({size} mục)", file=sys.stderr)
    cert_count = sum(
        (run(["security", "find-certificate", "-a", "-c", name, "-Z"]) or b"").count(b"SHA-1 hash:")
        for name in CERTIFICATE_NAMES
    )
    print(f"Chứng chỉ Apple Development trong Keychain: {cert_count}", file=sys.stderr)
    profiles = sum(len(glob.glob(os.path.join(os.path.expanduser(d), "*.*provision*"))) for d in PROFILE_DIRS)
    print(f"Provisioning profile: {profiles}", file=sys.stderr)


def main():
    preferences = xcode_preferences()
    candidates = teams_from_plist(preferences)
    try:
        with open(PROJECT_FILE, encoding="utf-8") as project:
            candidates += teams_from_project(project.read())
    except OSError:
        pass
    candidates += certificate_teams() + profile_teams()

    if "--diagnose" in sys.argv:
        diagnose(preferences)

    teams = best_teams(candidates)
    if not teams:
        return 1
    for rank, team_id, name in teams:
        print(f"{team_id}\t{name or '(không rõ tên)'}\t{SOURCES[rank]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
