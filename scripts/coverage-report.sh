#!/usr/bin/env bash
# ==============================================================================
# coverage-report.sh — EcoJournal unit test code coverage report
#
# Usage:
#   ./scripts/coverage-report.sh [--open]
#
#   --open    Open the HTML report in your default browser when done.
#   --fast    Skip the integration tests. Faster, but the report will
#             understate coverage of KeychainManager and PhotoStorageService.
#
# What it does:
#   1. Runs EcoJournalTests (unit tests only, skipping UITests) on the
#      iPhone 16 simulator with code coverage enabled.
#   2. Saves the .xcresult bundle to ./coverage/results.xcresult.
#   3. Exports a JSON coverage report  → ./coverage/coverage.json
#   4. Exports a plain-text summary    → ./coverage/coverage.txt
#   5. Generates a standalone HTML summary → ./coverage/index.html
#      (requires only Python 3, which ships with macOS / Xcode CLT)
#
# Coverage is scoped to the EcoJournal app target only (see the scheme's
# <CodeCoverageTargets> element), so test-bundle code never inflates numbers.
#
# Output artefacts (all under ./coverage/) are gitignored.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${PROJECT_ROOT}/EcoJournal.xcodeproj"
SCHEME="EcoJournal"
# Must be a device that exists on the *latest* installed simulator runtime —
# xcodebuild resolves a bare `name=` against OS:latest, so older-only devices
# (e.g. iPhone 16, which is iOS 18.5-only here) fail to resolve.
DESTINATION="${ECOJOURNAL_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"
RESULT_BUNDLE="${COVERAGE_DIR}/results.xcresult"
JSON_REPORT="${COVERAGE_DIR}/coverage.json"
TEXT_REPORT="${COVERAGE_DIR}/coverage.txt"
HTML_REPORT="${COVERAGE_DIR}/index.html"

OPEN_AFTER=false
FAST=false
for arg in "$@"; do
  case "$arg" in
    --open) OPEN_AFTER=true ;;
    --fast) FAST=true ;;
    *) ;;
  esac
done

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[94m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[92m[ OK ]\033[0m  %s\n' "$*"; }
fail()  { printf '\033[91m[FAIL]\033[0m  %s\n' "$*" >&2; }

# ------------------------------------------------------------------------------
# Step 1 — Prepare output directory
# ------------------------------------------------------------------------------
bold "=== EcoJournal Coverage Report ==="
info "Output directory: ${COVERAGE_DIR}"
rm -rf "${COVERAGE_DIR}"
mkdir -p "${COVERAGE_DIR}"

# ------------------------------------------------------------------------------
# Step 2 — Run unit tests with coverage
# ------------------------------------------------------------------------------
# The integration tests (KeychainManagerTests, PhotoStorageServiceTests) are
# what actually cover KeychainManager and PhotoStorageService. Skipping them
# does not just make the run faster, it makes the report wrong: KeychainManager
# reads 0.5% without them and 79.5% with them. So they run by default, and
# --fast opts out with a loud warning.
SKIP_ARGS=()
if $FAST; then
  SKIP_ARGS=(
    -skip-testing:EcoJournalTests/KeychainManagerTests
    -skip-testing:EcoJournalTests/PhotoStorageServiceTests
  )
  info "Running EcoJournalTests on simulator: ${DESTINATION}"
  fail "--fast: skipping integration tests. KeychainManager and"
  fail "PhotoStorageService will be reported as near-0% and the overall"
  fail "number will understate real coverage by roughly 5 points."
else
  info "Running EcoJournalTests on simulator: ${DESTINATION}"
  info "(Includes integration tests; pass --fast to skip them)"
fi

xcodebuild test \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -only-testing:EcoJournalTests \
  "${SKIP_ARGS[@]+"${SKIP_ARGS[@]}"}" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  -enableCodeCoverage YES \
  | xcpretty 2>/dev/null || true

# If xcpretty isn't installed, xcodebuild still ran; check for the bundle.
if [ ! -d "${RESULT_BUNDLE}" ]; then
  fail "No .xcresult bundle found at ${RESULT_BUNDLE}."
  fail "Check xcodebuild output above for errors."
  exit 1
fi
ok "Test run complete. Result bundle: ${RESULT_BUNDLE}"

# ------------------------------------------------------------------------------
# Step 3 — JSON coverage report
# ------------------------------------------------------------------------------
info "Generating JSON coverage report..."
xcrun xccov view --report --json "${RESULT_BUNDLE}" > "${JSON_REPORT}"
ok "JSON report: ${JSON_REPORT}"

# ------------------------------------------------------------------------------
# Step 4 — Plain-text summary
# ------------------------------------------------------------------------------
info "Generating plain-text coverage summary..."
xcrun xccov view --report "${RESULT_BUNDLE}" > "${TEXT_REPORT}"
ok "Text report: ${TEXT_REPORT}"

# Print the summary to the terminal
echo ""
bold "--- Coverage Summary ---"
cat "${TEXT_REPORT}"
echo ""

# ------------------------------------------------------------------------------
# Step 5 — HTML report (generated from JSON via Python 3)
# ------------------------------------------------------------------------------
info "Generating HTML report from JSON..."

python3 - "${JSON_REPORT}" "${HTML_REPORT}" << 'PYEOF'
import json
import sys
from pathlib import Path
from datetime import datetime

json_path = Path(sys.argv[1])
html_path = Path(sys.argv[2])

with open(json_path) as f:
    data = json.load(f)

def pct_color(p):
    if p >= 80:
        return "#28a745"   # green
    elif p >= 50:
        return "#fd7e14"   # orange
    else:
        return "#dc3545"   # red

def fmt_pct(p):
    return f"{p:.1f}%"

# Top-level targets (xccov JSON schema)
#
# xccov reports every target that produced coverage data, including the test
# bundles themselves. Counting those would measure how much of the test code
# ran, not how much of the app is tested — so keep only the app target.
targets = [t for t in data.get("targets", []) if not t.get("name", "").endswith(".xctest")]

# Build file rows — flatten all files from all targets, deduplicated by path
files = []
seen = set()
for target in targets:
    for f in target.get("files", []):
        path = f.get("path", "")
        if path in seen:
            continue
        seen.add(path)
        covered = f.get("coveredLines", 0)
        executable = f.get("executableLines", 0)
        pct = (covered / executable * 100) if executable > 0 else 0.0
        files.append({
            "name": Path(path).name,
            "path": path,
            "covered": covered,
            "executable": executable,
            "pct": pct,
        })

files.sort(key=lambda x: x["pct"])

# Overall numbers
total_covered    = sum(f["covered"]    for f in files)
total_executable = sum(f["executable"] for f in files)
overall_pct = (total_covered / total_executable * 100) if total_executable > 0 else 0.0

generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

rows = ""
for f in files:
    color = pct_color(f["pct"])
    bar_width = int(f["pct"])
    rows += f"""
        <tr>
          <td class="filename" title="{f['path']}">{f['name']}</td>
          <td style="text-align:right">{f['covered']}</td>
          <td style="text-align:right">{f['executable']}</td>
          <td>
            <div class="bar-wrap">
              <div class="bar" style="width:{bar_width}%;background:{color}"></div>
            </div>
          </td>
          <td style="text-align:right;color:{color};font-weight:600">{fmt_pct(f['pct'])}</td>
        </tr>"""

overall_color = pct_color(overall_pct)

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>EcoJournal — Code Coverage Report</title>
  <style>
    *{{box-sizing:border-box;margin:0;padding:0}}
    body{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
         background:#f5f5f7;color:#1d1d1f;padding:24px}}
    h1{{font-size:1.6rem;margin-bottom:4px}}
    .meta{{color:#6e6e73;font-size:.85rem;margin-bottom:24px}}
    .summary-card{{background:#fff;border-radius:12px;padding:20px 28px;
                   display:inline-flex;align-items:center;gap:24px;
                   box-shadow:0 1px 4px rgba(0,0,0,.1);margin-bottom:28px}}
    .big-pct{{font-size:3rem;font-weight:700;color:{overall_color}}}
    .summary-detail{{color:#6e6e73;font-size:.9rem;line-height:1.8}}
    table{{width:100%;border-collapse:collapse;background:#fff;
           border-radius:12px;overflow:hidden;
           box-shadow:0 1px 4px rgba(0,0,0,.1)}}
    th{{background:#f2f2f7;padding:10px 14px;text-align:left;
        font-size:.8rem;text-transform:uppercase;letter-spacing:.05em;color:#6e6e73}}
    td{{padding:8px 14px;border-top:1px solid #f2f2f7;font-size:.875rem;
        vertical-align:middle}}
    tr:hover td{{background:#f9f9fb}}
    .filename{{max-width:340px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
    .bar-wrap{{background:#e5e5ea;border-radius:4px;height:8px;width:140px}}
    .bar{{height:8px;border-radius:4px;transition:width .3s}}
    footer{{margin-top:24px;color:#6e6e73;font-size:.8rem;text-align:center}}
  </style>
</head>
<body>
  <h1>EcoJournal — Code Coverage</h1>
  <p class="meta">Generated {generated_at} &nbsp;|&nbsp; Scope: EcoJournal app target</p>

  <div class="summary-card">
    <div class="big-pct">{fmt_pct(overall_pct)}</div>
    <div class="summary-detail">
      <strong>{total_covered}</strong> / {total_executable} lines covered<br>
      <strong>{len(files)}</strong> source files measured
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>File</th>
        <th style="text-align:right">Covered</th>
        <th style="text-align:right">Executable</th>
        <th>Coverage</th>
        <th style="text-align:right">%</th>
      </tr>
    </thead>
    <tbody>{rows}
    </tbody>
  </table>

  <footer>Built with <code>xcrun xccov</code> + Python 3 &mdash; no extra dependencies</footer>
</body>
</html>"""

html_path.write_text(html, encoding="utf-8")
print(f"HTML report written to {html_path}")
PYEOF

ok "HTML report: ${HTML_REPORT}"

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
echo ""
bold "=== All done! ==="
echo "  JSON:  ${JSON_REPORT}"
echo "  Text:  ${TEXT_REPORT}"
echo "  HTML:  ${HTML_REPORT}"

if $OPEN_AFTER; then
  open "${HTML_REPORT}"
fi
