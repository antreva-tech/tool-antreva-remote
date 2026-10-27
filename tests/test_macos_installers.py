import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("macos_builder", ROOT / "scripts/build-macos-installers.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
BASH = ("C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else shutil.which("bash"))


class MacInstallerTests(unittest.TestCase):
    def setUp(self):
        self.policy = json.loads((ROOT / "config/antreva-client-policy.json").read_text())

    def test_policy_round_trip_preserves_shell_metacharacters(self):
        self.policy["rustdeskOptions"]["test-option"] = "quotes' and \" spaces $HOME $(exit 9); `exit 8`"
        commands = builder.policy_commands(self.policy)
        result = subprocess.run([BASH, "-c", 'apply_option() { printf "%s\\0%s\\0" "$1" "$2"; };\n' + commands],
                                check=True, capture_output=True)
        values = result.stdout.decode().split("\0")[:-1]
        self.assertEqual(dict(zip(values[::2], values[1::2])), self.policy["rustdeskOptions"])

    def test_missing_servers_and_unsafe_managed_defaults_are_rejected(self):
        for key, value in (("custom-rendezvous-server", ""), ("relay-server", "REPLACE_ME"),
                           ("key", ""), ("hide-tray", "Y"), ("enable-file-transfer", "N"),
                           ("verification-method", "use-temporary-password")):
            with self.subTest(key=key):
                original = self.policy["rustdeskOptions"][key]
                self.policy["rustdeskOptions"][key] = value
                with self.assertRaises(ValueError):
                    builder.policy_commands(self.policy)
                self.policy["rustdeskOptions"][key] = original

    def test_rendered_scripts_have_valid_bash_syntax(self):
        with tempfile.TemporaryDirectory() as temporary:
            for template, values in (
                ("preinstall.in", {"ARCH": "arm64", "LABEL": "Apple-Silicon"}),
                ("Configure-Antreva-Desk.command.in", {"VERSION": "1.0.6"}),
                ("apply-policy.sh.in", {"POLICY": builder.policy_commands(self.policy)}),
            ):
                target = Path(temporary) / template
                builder.write(target, builder.render(ROOT / "packaging/macos" / template, values), True)
                subprocess.run([BASH, "-n", target.as_posix()], check=True)
                self.assertNotIn(b"\r", target.read_bytes())

    def test_preinstall_architecture_os_and_upgrade_guards(self):
        # Execute the real generated preinstall with platform probes stubbed.
        # No package installation, service changes, or /Applications writes occur.
        script = builder.render(ROOT / "packaging/macos/preinstall.in",
                                {"ARCH": "arm64", "LABEL": "Apple-Silicon"})
        script = script.replace("/usr/sbin/sysctl", "mock_sysctl")
        script = script.replace("/usr/bin/sw_vers", "mock_sw_vers")
        script = script.replace("/usr/bin/pgrep", "mock_pgrep")
        cases = (
            ("arm64", "1", "14.0", "1", "/", 0),
            ("x86_64", "1", "14.0", "1", "/", 0),  # Rosetta on Apple Silicon
            ("x86_64", "0", "14.0", "1", "/", 1),
            ("arm64", "1", "11.0", "1", "/", 1),
            ("arm64", "1", "14.0", "0", "/", 1),  # running app
            ("arm64", "1", "14.0", "1", "/Volumes/Other", 1),
        )
        with tempfile.TemporaryDirectory() as temporary:
            script = script.replace("/Library/", Path(temporary).as_posix() + "/Library/")
            script = script.replace("/Applications/", Path(temporary).as_posix() + "/Applications/")
            for machine, silicon, version, running, destination, expected in cases:
                with self.subTest(machine=machine, silicon=silicon, version=version, running=running, destination=destination):
                    stubs = (f'uname() {{ if [[ "$1" == -s ]]; then echo Darwin; else echo {machine}; fi; }}\n'
                             f'mock_sysctl() {{ echo {silicon}; }}\n'
                             f'mock_sw_vers() {{ echo {version}; }}\n'
                             f'mock_pgrep() {{ return {running}; }}\n')
                    result = subprocess.run([BASH, "-c", stubs + script, "preinstall", "pkg", "/", destination],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, expected, result.stderr)
            daemon = Path(temporary) / "Library/LaunchDaemons/com.carriez.RustDesk_service.plist"
            daemon.parent.mkdir(parents=True)
            daemon.touch()
            stubs = ('uname() { echo Darwin; }; mock_sysctl() { echo 1; }; '
                     'mock_sw_vers() { echo 14.0; }; mock_pgrep() { return 1; };\n')
            result = subprocess.run([BASH, "-c", stubs + script], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("existing RustDesk service", result.stderr)

    def test_policy_verification_rejects_false_success(self):
        # RustDesk may exit zero without applying an option: readback must fail.
        script = (ROOT / "packaging/macos/apply-policy.sh.in").read_text()
        function = script[script.index("apply_option() {"):script.index("@@POLICY@@")]
        function = function.replace('"$binary"', "mock_binary").replace("/bin/sleep", "mock_sleep")
        for returned, expected in (("expected", 0), ("wrong-server", 7), ("", 7)):
            stubs = (f'mock_binary() {{ [[ "$#" == 2 ]] && printf "%s" "{returned}"; return 0; }}\n'
                     'mock_sleep() { :; }; fail() { exit 7; }; binary=unused\n')
            result = subprocess.run([BASH, "-c", stubs + function + '\napply_option key expected'], capture_output=True)
            self.assertEqual(result.returncode, expected)


if __name__ == "__main__":
    unittest.main()
