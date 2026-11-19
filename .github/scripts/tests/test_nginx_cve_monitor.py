import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "nginx_cve_monitor.py"
SPEC = importlib.util.spec_from_file_location("nginx_cve_monitor", SCRIPT)
monitor = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(monitor)


class NginxCveMonitorTest(unittest.TestCase):
    def test_patched_cves_are_found_in_names_and_contents(self):
        with tempfile.TemporaryDirectory() as directory:
            patch_directory = Path(directory)
            (patch_directory / "28_nginx-1.27.1-CVE-2025-23419.patch").write_text(
                "Fixes CVE-2025-23419\n", encoding="utf-8"
            )
            (patch_directory / "security.patch").write_text(
                "Also fixes cve-2026-12345.\n", encoding="utf-8"
            )

            self.assertEqual(
                monitor.patched_cves(patch_directory),
                {"CVE-2025-23419", "CVE-2026-12345"},
            )

    def test_rejected_records_are_not_candidates(self):
        self.assertFalse(
            monitor.is_wanted_cve(
                {"cve": {"id": "CVE-2026-12345", "vulnStatus": "Rejected"}}
            )
        )
        self.assertTrue(
            monitor.is_wanted_cve(
                {"cve": {"id": "CVE-2026-12345", "vulnStatus": "Analyzed"}}
            )
        )

    @patch.object(monitor, "request_json")
    def test_active_copilot_tasks_are_used_for_deduplication(self, request):
        request.side_effect = [
            {
                "tasks": [
                    {"id": "active-task", "state": "in_progress"},
                    {"id": "failed-task", "state": "failed"},
                ]
            },
            {
                "id": "active-task",
                "state": "in_progress",
                "sessions": [{"prompt": "Assess CVE-2026-12345"}],
            },
        ]

        self.assertEqual(
            monitor.tracked_in_copilot_tasks("rancher/ingress-nginx", "token"),
            {"CVE-2026-12345"},
        )

    def test_prompt_requires_impact_analysis_before_backport(self):
        prompt = monitor.render_prompt(
            "rancher/ingress-nginx",
            "1.27.1",
            {
                "id": "CVE-2026-12345",
                "descriptions": [
                    {"lang": "en", "value": "A buffer overflow in nginx."}
                ],
                "references": [{"url": "https://nginx.org/security/advisory"}],
            },
        )

        self.assertIn("Do not assume that an NVD CPE match", prompt)
        self.assertIn("without opening a PR", prompt)
        self.assertIn("hardened-nginx-1.15.x", prompt)
        self.assertIn("https://nginx.org/security/advisory", prompt)

    @patch.object(monitor, "request_json")
    def test_nvd_pagination_uses_cpe_and_recent_modifications(self, request):
        request.side_effect = [
            {
                "totalResults": 2,
                "vulnerabilities": [{"cve": {"id": "CVE-2026-1"}}],
            },
            {
                "totalResults": 2,
                "vulnerabilities": [{"cve": {"id": "CVE-2026-2"}}],
            },
        ]

        results = monitor.fetch_nginx_cves(30, None)

        self.assertEqual(len(results), 2)
        self.assertIn(
            "cpeName=cpe%3A2.3%3Aa%3Af5%3Anginx",
            request.call_args_list[0].args[0],
        )
        self.assertIn("startIndex=1", request.call_args_list[1].args[0])


if __name__ == "__main__":
    unittest.main()
