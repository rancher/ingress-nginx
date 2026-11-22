#!/usr/bin/env python3

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path


NVD_API_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"
GITHUB_API_URL = "https://api.github.com"
NGINX_CPE = "cpe:2.3:a:f5:nginx:*:*:*:*:*:*:*:*"
RESULTS_PER_PAGE = 2000
CVE_PATTERN = re.compile(r"CVE-\d{4}-\d{4,}", re.IGNORECASE)
TERMINAL_COPILOT_STATES = {"cancelled", "failed", "timed_out"}


def request_json(url: str, headers: dict[str, str] | None = None) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "rancher-ingress-nginx-cve-monitor",
            **(headers or {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{url} returned HTTP {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Unable to request {url}: {error.reason}") from error


def fetch_nginx_cves(lookback_days: int, api_key: str | None) -> list[dict]:
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=lookback_days)
    start_index = 0
    vulnerabilities = []
    headers = {"apiKey": api_key} if api_key else None

    while True:
        query = urllib.parse.urlencode(
            {
                "cpeName": NGINX_CPE,
                "lastModStartDate": start.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                "lastModEndDate": end.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                "resultsPerPage": RESULTS_PER_PAGE,
                "startIndex": start_index,
            }
        )
        result = request_json(f"{NVD_API_URL}?{query}", headers)
        page = result.get("vulnerabilities", [])
        vulnerabilities.extend(page)

        total_results = int(result.get("totalResults", len(vulnerabilities)))
        start_index += len(page)
        if not page or start_index >= total_results:
            return vulnerabilities


def english_description(cve: dict) -> str:
    descriptions = cve.get("descriptions", [])
    for description in descriptions:
        if description.get("lang") == "en" and description.get("value"):
            return " ".join(description["value"].split())
    return "No English description was provided by NVD."


def is_wanted_cve(vulnerability: dict) -> bool:
    cve = vulnerability.get("cve", {})
    return (
        bool(CVE_PATTERN.fullmatch(cve.get("id", "")))
        and cve.get("vulnStatus") != "Rejected"
    )


def patched_cves(patch_directory: Path) -> set[str]:
    patched = set()
    for patch in patch_directory.iterdir() if patch_directory.exists() else ():
        if not patch.is_file():
            continue
        try:
            contents = patch.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            contents = patch.read_text(encoding="utf-8", errors="replace")
        patched.update(match.upper() for match in CVE_PATTERN.findall(contents))
        patched.update(match.upper() for match in CVE_PATTERN.findall(patch.name))
    return patched


def tracked_in_github(repository: str, cve_id: str, token: str) -> bool:
    query = urllib.parse.quote(f'repo:{repository} "{cve_id}"')
    url = f"{GITHUB_API_URL}/search/issues?q={query}"
    result = request_json(
        url,
        {
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    return int(result.get("total_count", 0)) > 0


def tracked_in_copilot_tasks(repository: str, token: str) -> set[str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2026-03-10",
    }
    base_url = f"{GITHUB_API_URL}/agents/repos/{repository}/tasks"
    page = 1
    tasks = []
    while True:
        result = request_json(f"{base_url}?per_page=100&page={page}", headers)
        page_tasks = result.get("tasks", []) if isinstance(result, dict) else result
        tasks.extend(page_tasks)
        if len(page_tasks) < 100:
            break
        page += 1

    tracked = set()
    for task in tasks:
        if task.get("state") in TERMINAL_COPILOT_STATES:
            continue
        task_details = task
        if task.get("id"):
            task_details = request_json(f"{base_url}/{task['id']}", headers)
        tracked.update(
            match.upper()
            for match in CVE_PATTERN.findall(json.dumps(task_details, sort_keys=True))
        )
    return tracked


def render_prompt(repository: str, nginx_version: str, cve: dict) -> str:
    cve_id = cve["id"]
    description = english_description(cve)
    references = [
        reference["url"]
        for reference in cve.get("references", [])
        if reference.get("url")
    ]
    reference_list = "\n".join(
        f"- {reference}" for reference in dict.fromkeys(references[:12])
    )
    if not reference_list:
        reference_list = f"- https://nvd.nist.gov/vuln/detail/{cve_id}"

    return f"""<!-- nginx-cve-monitor: {cve_id} -->

Analyze and remediate upstream nginx vulnerability **{cve_id}** for `{repository}`.

## Vulnerability data

- **Pinned nginx:** {nginx_version} (`images/nginx/rootfs/version.sh`)
- **Published:** {cve.get("published", "unknown")}
- **Last modified:** {cve.get("lastModified", "unknown")}
- **NVD description:** {description}

## Source references

{reference_list}

## Required workflow

1. Determine whether the vulnerable code and configuration are present in this image's pinned nginx {nginx_version} source and enabled build modules (`images/nginx/rootfs/build.sh`). Do not assume that an NVD CPE match means this image is affected.
2. Compare the current patch stack in `images/nginx/rootfs/patches/` and recent backports in PR #246 and PR #248 for version adaptation and patch naming conventions.
3. If affected, find the authoritative upstream nginx fix and adapt it to nginx {nginx_version}. Preserve the purpose of the upstream fix; do not replace it with a workaround, version bump, unrelated refactor, or a patch copied without provenance.
4. Add the smallest applicable backport under `images/nginx/rootfs/patches/` using the next numeric prefix and the filename `<prefix>_nginx-{nginx_version}-{cve_id}.patch`. Use `git format-patch`-style metadata and identify the upstream commit/source and affected CVE in the patch header.
5. Validate that every patch in `images/nginx/rootfs/patches/` applies cleanly in order to a pristine nginx {nginx_version} source tree. Run the base image build or the narrowest equivalent build that actually exercises the patched source.
6. Open a PR against `hardened-nginx-1.15.x` that follows `.github/PULL_REQUEST_TEMPLATE.md`, links this issue, explains the affected-path analysis, cites upstream evidence, and records the validation performed.
7. Do not merge the PR. Do not modify unrelated files. Do not create a PR until the impact analysis confirms the image is affected and the backport has been validated.
8. If the image is not affected, finish the task with a report containing the evidence and reasoning (including vulnerable versions, modules, and relevant local code), without opening a PR or changing files.
"""


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find recent nginx CVEs that need assessment by Copilot."
    )
    parser.add_argument("--lookback-days", type=int, default=30)
    parser.add_argument(
        "--patch-directory",
        type=Path,
        default=Path("images/nginx/rootfs/patches"),
    )
    parser.add_argument(
        "--version-file",
        type=Path,
        default=Path("images/nginx/rootfs/version.sh"),
    )
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def read_nginx_version(version_file: Path) -> str:
    match = re.search(
        r"^export NGINX_VERSION=(\S+)$",
        version_file.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    if not match:
        raise RuntimeError(f"NGINX_VERSION was not found in {version_file}")
    return match.group(1)


def main() -> int:
    args = parse_arguments()
    if not 1 <= args.lookback_days <= 120:
        raise ValueError("--lookback-days must be between 1 and 120")

    repository = os.environ.get("GITHUB_REPOSITORY")
    github_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    copilot_token = os.environ.get("COPILOT_AGENT_TOKEN")
    if not repository:
        raise RuntimeError("GITHUB_REPOSITORY is required")
    if not github_token:
        raise RuntimeError("GITHUB_TOKEN or GH_TOKEN is required")
    if not copilot_token:
        raise RuntimeError("COPILOT_AGENT_TOKEN is required")

    nginx_version = read_nginx_version(args.version_file)
    already_patched = patched_cves(args.patch_directory)
    already_dispatched = tracked_in_copilot_tasks(repository, copilot_token)
    vulnerabilities = fetch_nginx_cves(
        args.lookback_days, os.environ.get("NVD_API_KEY")
    )
    candidates = []

    for vulnerability in vulnerabilities:
        if not is_wanted_cve(vulnerability):
            continue
        cve = vulnerability["cve"]
        cve_id = cve["id"].upper()
        if cve_id in already_patched or cve_id in already_dispatched:
            continue
        if tracked_in_github(repository, cve_id, github_token):
            continue
        candidates.append(
            {
                "cve_id": cve_id,
                "prompt": render_prompt(repository, nginx_version, cve),
            }
        )

    candidates.sort(key=lambda candidate: candidate["cve_id"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(candidates, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"Found {len(vulnerabilities)} recently modified nginx CVE records; "
        f"queued {len(candidates)} for Copilot assessment."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"nginx CVE monitor failed: {error}", file=sys.stderr)
        sys.exit(1)
