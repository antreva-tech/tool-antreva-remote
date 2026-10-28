#!/usr/bin/env python3
"""Build architecture-specific macOS pkg installers from pinned RustDesk DMGs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def render(template, values):
    result = template.read_text(encoding="utf-8")
    for key, value in values.items():
        result = result.replace(f"@@{key}@@", value)
    if "@@" in result:
        raise ValueError(f"Unresolved template token in {template}")
    return result


def policy_commands(policy):
    options = policy["rustdeskOptions"]
    for key in ("custom-rendezvous-server", "relay-server", "key"):
        if not options.get(key) or "REPLACE" in options[key]:
            raise ValueError(f"Missing managed server option: {key}")
    for key, expected in {"hide-tray": "N", "enable-file-transfer": "Y",
                          "verification-method": "use-permanent-password"}.items():
        if options.get(key) != expected:
            raise ValueError(f"Managed policy requires {key}={expected}")
    if any(not isinstance(value, str) or "\n" in value or "\r" in value
           for value in options.values()):
        raise ValueError("Policy values must be single-line strings")
    return "\n".join(f"apply_option {shlex.quote(key)} {shlex.quote(value)}"
                     for key, value in options.items())


def write(path, content, executable=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    path.chmod(0o755 if executable else 0o644)


def build(arch, output):
    manifest = json.loads((ROOT / "config/macos-payloads.json").read_text())
    policy = json.loads((ROOT / "config/antreva-client-policy.json").read_text())
    commands = policy_commands(policy)
    payload = manifest["payloads"][arch]
    version = manifest["version"]
    name = f"Antreva-Desk-{version}-macOS-{payload['label']}"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="antreva-macos-") as temporary:
        stage = Path(temporary)
        dmg = stage / payload["file"]
        url = f"https://github.com/rustdesk/rustdesk/releases/download/{manifest['rustdeskVersion']}/{payload['file']}"
        with urllib.request.urlopen(url, timeout=120) as response, dmg.open("wb") as dest:
            shutil.copyfileobj(response, dest)
        if sha256(dmg) != payload["sha256"]:
            raise ValueError("RustDesk DMG SHA-256 mismatch; refusing to package")
        mounted = plistlib.loads(subprocess.check_output([
            "hdiutil", "attach", "-readonly", "-nobrowse", "-plist", str(dmg)]))
        device = next(item["dev-entry"] for item in mounted["system-entities"] if "dev-entry" in item)
        try:
            mount = next(Path(item["mount-point"]) for item in mounted["system-entities"] if "mount-point" in item)
            source = mount / "RustDesk.app"
            run("codesign", "--verify", "--deep", "--strict", str(source))
            app = stage / "root/Applications/RustDesk.app"
            app.parent.mkdir(parents=True)
            run("ditto", str(source), str(app))
        finally:
            run("hdiutil", "detach", device)
        run("codesign", "--verify", "--deep", "--strict", str(app))
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        if info["CFBundleShortVersionString"] != manifest["rustdeskVersion"]:
            raise ValueError("Unexpected RustDesk app version")
        binary = app / "Contents/MacOS/RustDesk"
        arches = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
        if arch not in arches:
            raise ValueError(f"Expected native architecture {arch}, found {arches}")
        setup_dir = stage / "root/Applications/Antreva Desk"
        write(setup_dir / "Configure Antreva Desk.command", render(
            ROOT / "packaging/macos/Configure-Antreva-Desk.command.in",
            {"VERSION": version}), executable=True)
        write(setup_dir / "Apply Antreva Policy.sh", render(
            ROOT / "packaging/macos/apply-policy.sh.in", {"POLICY": commands}), executable=True)
        shutil.copy2(ROOT / "docs/operations/MACOS-SUPPORT.md", setup_dir / "README.md")
        source_offer = (f"RustDesk {manifest['rustdeskVersion']} (unmodified app), AGPL-3.0.\n"
                        f"Corresponding source: https://github.com/rustdesk/rustdesk/tree/{manifest['sourceCommit']}\n"
                        "Antreva installer source: https://github.com/antreva-tech/tool-antreva-remote\n")
        write(setup_dir / "SOURCE-OFFER.txt", source_offer)
        scripts = stage / "scripts"
        write(scripts / "preinstall", render(ROOT / "packaging/macos/preinstall.in",
              {"ARCH": arch, "LABEL": payload["label"]}), executable=True)
        # Explicitly replace bundles in /Applications; never relocate an older copy.
        components = stage / "components.plist"
        run("pkgbuild", "--analyze", "--root", str(stage / "root"), str(components))
        entries = plistlib.loads(components.read_bytes())
        for entry in entries:
            entry["BundleIsRelocatable"] = False
            entry["BundleHasStrictIdentifier"] = True
            entry["BundleOverwriteAction"] = "upgrade"
        components.write_bytes(plistlib.dumps(entries))
        package = output / f"{name}.pkg"
        run("pkgbuild", "--root", str(stage / "root"), "--scripts", str(scripts),
            "--component-plist", str(components), "--identifier", f"com.antreva.desk.macos.{arch}",
            "--version", version, "--install-location", "/", "--ownership", "recommended", str(package))
        # No root postinstall: enrollment always runs visibly in the user's session.
        run("pkgutil", "--expand-full", str(package), str(stage / "expanded"))
        installed = list((stage / "expanded").rglob("RustDesk.app/Contents/Info.plist"))
        if not installed:
            raise ValueError("Generated package is missing RustDesk.app")
        run("codesign", "--verify", "--deep", "--strict", str(installed[0].parent.parent))
        write(output / f"{name}.sha256.txt", f"{sha256(package)}  {package.name}\n")
        write(output / f"{name}.provenance.json", json.dumps({
            "antrevaVersion": version, "architecture": arch,
            "rustdeskVersion": manifest["rustdeskVersion"], "payloadUrl": url,
            "payloadSha256": payload["sha256"], "rustdeskSourceCommit": manifest["sourceCommit"],
            "installerSourceCommit": os.environ.get("GITHUB_SHA", "local-uncommitted"),
            "packageSha256": sha256(package), "installerSigned": False,
            "status": "preview; live Mac onboarding and remote-session testing required"
        }, indent=2) + "\n")
        print(f"Built {package}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arch", choices=("x86_64", "arm64"), required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/macos")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("Build on macOS with Apple's command line tools (or GitHub Actions)")
    build(args.arch, args.output.resolve())
