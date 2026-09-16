# Build and verification status

Current source: **0.13.1, build 21**. Updated 2026-09-15.

| Check | Status |
| --- | --- |
| Local optimized Apple Silicon build, Swift warnings as errors | Passed |
| Built-in regression suite | Passed |
| Layout checks | 2,640 cases across 528 available styles on the audit machine |
| Xcode Release build, 0.13.1 | Passed |
| Unsigned archive and asset catalog, 0.12.3 | Passed; archive not checked into source |
| Sandbox/hardened-runtime clean launch and installed-font export, 0.12.3 | Passed |
| Google preview UI, 0.13.1 | Installed and remotely loaded samples verified |
| GitHub-hosted checks | See the live workflow badge; results are not inferred from local tests |
| Distribution signing / App Store Connect validation | Pending |
| macOS 13 and second-machine testing | Pending |
| Intel support | Not shipped |

Regression checks cover catalog/search/filtering, persistence and corrupt-data preservation, family merge/split and shortlist remapping, tags, variable settings, OpenType parsing and actual ligature changes, duplicate hashing, export collisions, and preview text integrity. Layout counts depend on fonts available on the machine. Tests do not download fonts or upload personal data.

Manual checks do not certify every font/script or failure case. Offline preview failure, denied folder access after relocation/revocation, broader accessibility testing and clean second-device testing remain on the release checklist. Rebuild the signed distribution archive before any submission.

Local bundles are ad-hoc signed. They are not notarized downloads and are not App Store packages. A passing CI run does not guarantee App Review approval.
