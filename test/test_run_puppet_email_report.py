"""Exercise the rendered Linux email function without SMTP or root access."""

import email
import email.policy
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


TEMPLATE = pathlib.Path(__file__).parents[1] / "modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb"
FUNCTION = "function email_report {" + TEMPLATE.read_text().split(
    "function email_report {", 1
)[1].split("\n}\n", 1)[0] + "\n}\n"

SMTP_STUB = '''
import json
import os
import pathlib
import stat
import sys

class SMTPException(Exception):
    pass

class SMTP:
    def __init__(self, host):
        self.host = host
        if os.environ["TEST_SMTP_RESULT"] == "connect_failure":
            raise OSError("simulated connection failure")

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        pass

    def send_message(self, message, from_addr, to_addrs):
        body = pathlib.Path(sys.argv[1])
        assert stat.S_IMODE(body.stat().st_mode) == 0o600
        assert stat.S_IMODE(body.parent.stat().st_mode) == 0o700
        assert "TEST_LOG_PAYLOAD" not in os.environ
        if os.environ["TEST_SMTP_RESULT"] == "send_failure":
            raise SMTPException("simulated send failure")
        capture = pathlib.Path(os.environ["TEST_CAPTURE"])
        capture.write_text(json.dumps({
            "host": self.host, "sender": from_addr, "recipients": to_addrs,
            "message": message.as_string(),
        }), encoding="utf-8")
'''


class EmailReportTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.directory = pathlib.Path(self.tempdir.name)
        (self.directory / "smtplib.py").write_text(SMTP_STUB)
        self.capture = self.directory / "capture.json"
        self.marker = self.directory / "executed"

    def run_report(self, body, subject="Puppet failed", smtp_result="success",
                   smtp_host="smtp.example.com", sender_host="worker.example.com",
                   receiver="operator@example.com"):
        rendered = subprocess.run(
            ["ruby", "-rerb", "-e", "@smtp_relay_host=ARGV.fetch(0); print ERB.new(STDIN.read).result", smtp_host],
            input=FUNCTION, text=True, capture_output=True, check=True,
        ).stdout
        # Redirect only root staging into a private fixture; execute the actual
        # rendered function and Python heredoc with a fake SMTP transport.
        script = '''
set -eu
mktemp() {
    [ "$*" = '-d /root/puppet-email.XXXXXX' ] || return 1
    command mktemp -d "${TEST_DIRECTORY}/puppet-email.XXXXXX"
}
'''+ rendered + '''
FQDN=$TEST_SENDER_HOST
PUPPET_MAIL=$TEST_RECEIVER
PYTHON_BIN=$TEST_PYTHON
email_report "$TEST_SUBJECT" "$(cat "$TEST_BODY_FILE")"
'''
        body_file = self.directory / "input-log"
        body_file.write_text(body, encoding="utf-8")
        environment = dict(os.environ, PYTHONPATH=str(self.directory),
                           TEST_DIRECTORY=str(self.directory), TEST_CAPTURE=str(self.capture),
                           TEST_SMTP_RESULT=smtp_result, TEST_PYTHON=sys.executable,
                           TEST_SUBJECT=subject, TEST_BODY_FILE=str(body_file),
                           TEST_SENDER_HOST=sender_host, TEST_RECEIVER=receiver)
        result = subprocess.run(["bash", "-c", script], env=environment,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(list(self.directory.glob("puppet-email.*")), [])
        self.assertFalse(self.marker.exists(), "report data executed as code")
        return result

    def captured_message(self):
        capture = json.loads(self.capture.read_text())
        message = email.message_from_string(capture["message"], policy=email.policy.default)
        return capture, message

    def test_normal_email_and_private_staging(self):
        result = self.run_report("Error: example failure")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Successfully sent email", result.stdout)
        capture, message = self.captured_message()
        self.assertEqual(capture["host"], "smtp.example.com")
        self.assertEqual(capture["sender"], "root@worker.example.com")
        self.assertEqual(capture["recipients"], ["operator@example.com"])
        self.assertEqual(message["Subject"], "Puppet failed")
        self.assertEqual(message.get_content(), "Error: example failure\n")

    def test_python_shell_and_unicode_body_remain_data(self):
        body = ('"""\n__import__("pathlib").Path(' + repr(str(self.marker)) +
                ').touch()\n# """\n$(touch ' + str(self.marker) +
                ')\n`touch ' + str(self.marker) + '`\nUnicode: café 日本語')
        result = self.run_report(body)
        self.assertEqual(result.returncode, 0, result.stderr)
        _, message = self.captured_message()
        self.assertEqual(message.get_content(), body + "\n")

    def test_metadata_quotes_and_shell_payloads_remain_data(self):
        subject = 'failure """ $(touch ' + str(self.marker) + ') café'
        host = "smtp'; touch " + str(self.marker) + "; #"
        result = self.run_report("failure", subject=subject, smtp_host=host)
        self.assertEqual(result.returncode, 0, result.stderr)
        capture, message = self.captured_message()
        self.assertEqual(capture["host"], host)
        self.assertEqual(message["Subject"], subject)

    def test_large_log_is_not_passed_in_environment_or_python_arguments(self):
        body = "large log line café\n" * 100_000
        result = self.run_report(body)
        self.assertEqual(result.returncode, 0, result.stderr)
        _, message = self.captured_message()
        self.assertEqual(message.get_content(), body)

    def test_smtp_failures_are_reported_and_staging_is_cleaned(self):
        for smtp_result in ("connect_failure", "send_failure"):
            with self.subTest(smtp_result=smtp_result):
                result = self.run_report("failure", smtp_result=smtp_result)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Error: unable to send email", result.stdout)
                self.assertFalse(self.capture.exists())

    def test_header_newlines_are_rejected_without_sending(self):
        for metadata in (
            {"subject": "failure\nBcc: attacker@example.com"},
            {"sender_host": "host\nBcc: attacker@example.com"},
            {"receiver": "operator@example.com\nBcc: attacker@example.com"},
        ):
            with self.subTest(metadata=metadata):
                result = self.run_report("failure", **metadata)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Error: unable to send email", result.stdout)
                self.assertFalse(self.capture.exists())


if __name__ == "__main__":
    unittest.main()
