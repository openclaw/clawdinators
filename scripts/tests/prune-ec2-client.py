#!/usr/bin/env python3
"""Exercise the real AWS CLI against a loopback-only EC2 Query API fixture."""

import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs


SCRIPT = Path(__file__).resolve().parents[1] / "prune-clawdinator-ami-history.sh"


class RetentionClientTest(unittest.TestCase):
    def run_scenario(self, scenario):
        calls = []

        class EC2Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_POST(self):
                query = parse_qs(self.rfile.read(int(self.headers["Content-Length"])).decode())
                action = query["Action"][0]
                calls.append(query)
                if (scenario == "instance-error" and action == "DescribeInstances") or (
                    scenario == "image-error" and action == "DescribeImages"
                ):
                    self.send_response(403)
                    body = "<Response><Errors><Error><Code>UnauthorizedOperation</Code><Message>fixture denied inventory</Message></Error></Errors></Response>"
                else:
                    self.send_response(200)
                    if action == "DescribeInstances":
                        instances = "<item><instancesSet><item><imageId>ami-old</imageId></item></instancesSet></item>" if scenario == "in-use" else ""
                        result = f"<reservationSet>{instances}</reservationSet>"
                    elif action == "DescribeImages":
                        images = "" if scenario == "empty" else "".join(
                            f"<item><imageId>ami-{name}</imageId><name>{name}</name><creationDate>2026-0{month}-01T00:00:00Z</creationDate><rootDeviceName>/dev/xvda</rootDeviceName><blockDeviceMapping><item><deviceName>/dev/xvda</deviceName><ebs><snapshotId>snap-{name}</snapshotId></ebs></item></blockDeviceMapping></item>"
                            for name, month in (("old", 1), ("new", 2))
                        )
                        result = f"<imagesSet>{images}</imagesSet>"
                    elif action in ("DeregisterImage", "DeleteSnapshot"):
                        result = "<return>true</return>"
                    else:
                        result = ""
                    body = f'<{action}Response xmlns="http://ec2.amazonaws.com/doc/2016-11-15/">{result}</{action}Response>'
                data = body.encode()
                self.send_header("Content-Type", "text/xml")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        with tempfile.TemporaryDirectory() as home, HTTPServer(("127.0.0.1", 0), EC2Handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            env = {key: value for key, value in os.environ.items() if not key.startswith("AWS_")}
            env.update(
                HOME=home,
                AWS_CONFIG_FILE=os.devnull,
                AWS_SHARED_CREDENTIALS_FILE=os.devnull,
                AWS_ACCESS_KEY_ID="testing",
                AWS_SECRET_ACCESS_KEY="testing",
                AWS_EC2_METADATA_DISABLED="true",
                AWS_ENDPOINT_URL_EC2=f"http://127.0.0.1:{server.server_port}",
                AWS_REGION="us-east-1",
                AWS_DEFAULT_REGION="us-east-1",
                AWS_MAX_ATTEMPTS="1",
                AWS_PAGER="",
                NO_PROXY="127.0.0.1",
                no_proxy="127.0.0.1",
                KEEP_COUNT="1",
                APPLY="false" if scenario == "dry-run" else "true",
            )
            try:
                result = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True, timeout=60)
            finally:
                server.shutdown()
                thread.join()

        actions = [call["Action"][0] for call in calls]
        self.assertIn("DescribeInstances", actions, result.stderr)
        if scenario.endswith("-error"):
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("fixture denied inventory", result.stderr)
            if scenario == "instance-error":
                self.assertEqual(actions, ["DescribeInstances"])
        else:
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("DescribeImages", actions)
        mutations = [call for call in calls if call["Action"][0] not in ("DescribeInstances", "DescribeImages")]
        if scenario == "prune":
            self.assertEqual([call["Action"][0] for call in mutations], ["DeregisterImage", "DeleteSnapshot"])
            self.assertEqual(mutations[0]["ImageId"], ["ami-old"])
            self.assertEqual(mutations[1]["SnapshotId"], ["snap-old"])
        else:
            self.assertEqual(mutations, [])

    def test_retention(self):
        for scenario in ("instance-error", "image-error", "empty", "in-use", "prune", "dry-run"):
            with self.subTest(scenario=scenario):
                self.run_scenario(scenario)


if __name__ == "__main__":
    unittest.main(verbosity=2)
