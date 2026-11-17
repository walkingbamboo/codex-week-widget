"""Regression checks for Codex's transparent rollout compression."""
import datetime
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/collect_codex_week.sh"
ZSTD = shutil.which("zstd") or "/opt/homebrew/bin/zstd"


class CollectorTests(unittest.TestCase):
    def test_compressed_history_matches_plain_and_errors_preserve_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rollout = root / "rollout.jsonl"
            output = root / "snapshot.json"
            now = int(datetime.datetime.now().timestamp())
            timestamp = datetime.datetime.fromtimestamp(
                now, datetime.timezone.utc
            ).strftime("%Y-%m-%dT%H:%M:%SZ")
            payloads = [
                {"type": "task_started", "turn_id": "fixture-turn"},
                {"type": "task_complete", "turn_id": "fixture-turn", "duration_ms": 123000},
                {"type": "token_count", "info": {"last_token_usage": {"total_tokens": 456}},
                 "rate_limits": {"primary": {"used_percent": 53,
                                              "window_minutes": 10080,
                                              "resets_at": now + 86400}}},
            ]
            rollout.write_text("".join(json.dumps(
                {"timestamp": timestamp, "type": "event_msg", "payload": payload},
                separators=(",", ":")
            ) + "\n" for payload in payloads))
            with sqlite3.connect(root / "state_5.sqlite") as connection:
                connection.execute("create table threads (rollout_path text, updated_at integer)")
                connection.execute("insert into threads values (?, ?)", (str(rollout), now))
            environment = dict(os.environ, CODEX_ROOT=str(root),
                               CODEX_WEEK_CONFIG=str(root / "no-config"),
                               CODEX_WEEK_TIMEZONE="Asia/Kuala_Lumpur")

            def collect():
                return subprocess.run(["/bin/zsh", str(SCRIPT), str(output)],
                                      env=environment, capture_output=True, text=True)

            result = collect()
            self.assertEqual(result.returncode, 0, result.stderr)
            plain = json.loads(output.read_text())
            self.assertEqual(plain["remainingPercent"], 47)
            self.assertEqual(plain["weekTokens"], 456)
            self.assertEqual(plain["runtimeSeconds"], 123)
            self.assertEqual(plain["closureCompletedTasks"], 1)
            compressed = Path(str(rollout) + ".zst")
            subprocess.run([ZSTD, "-q", str(rollout), "-o", str(compressed)], check=True)
            rollout.unlink()
            result = collect()
            self.assertEqual(result.returncode, 0, result.stderr)
            packed = json.loads(output.read_text())
            for key in ("weekTokens", "dailyTokens", "runtimeSeconds", "completedTasks",
                        "closureCompletedTasks", "remainingPercent", "resetAt"):
                self.assertEqual(packed[key], plain[key], key)

            preserved = output.read_bytes()
            compressed.write_bytes(b"corrupt zstd data")
            result = collect()
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_bytes(), preserved)
            self.assertTrue(result.stderr)
            compressed.unlink()
            result = collect()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("rollout unavailable", result.stderr)
            self.assertEqual(output.read_bytes(), preserved)


if __name__ == "__main__":
    unittest.main()
