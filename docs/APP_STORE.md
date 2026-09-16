# App Store checklist

- [x] Native macOS app and shared Xcode scheme.
- [x] Sandbox and hardened-runtime configuration.
- [x] Icon asset catalog and privacy manifest.
- [x] Local build and regression checks.
- [ ] Active paid Apple Developer team and registered production bundle identifier.
- [ ] Final public version, distribution-signed archive, Organizer validation and App Store Connect upload.
- [ ] TestFlight/second-Mac testing and verification of the declared macOS 13 minimum (or a justified deployment-target change).
- [ ] Keyboard, VoiceOver, reduced transparency, increased contrast, denied-file-access and offline/download tests on the final distribution build.
- [ ] Public support/contact and privacy-policy URLs.
- [ ] Store screenshots, description, keywords, copyright, price and territories.
- [ ] Age rating, privacy, export-compliance, applicable EU trader-status and review-contact information.
- [ ] Applicable agreements/tax/banking setup if selling the app.
- [ ] User-authorized migration of an existing local library into the Store sandbox, if supporting upgrades from local builds.

The production bundle identifier must replace `local.fontshelf.app`. Never commit signing credentials or provisioning profiles. `archive-store.sh` takes team and bundle identifiers from environment variables and only archives; it does not upload.

The Store container does not automatically inherit local collections, tags, settings or folder permissions. A migration flow remains outstanding. Session activation and font export should be checked with representative installed and imported fonts under the final signed entitlement set.

## Review notes draft

FontShelf previews and organizes fonts available on the Mac and in user-selected folders. It does not modify original font files. Google font browsing retrieves public preview font files from GitHub; explicit downloads store font files and their license locally. Preview text and the user's library are not uploaded. Temporary activation uses Core Text session registration and is cleared on normal quit. Export copies originals to a user-selected destination. Adobe support exports static JSX scripts for users to run manually; FontShelf sends no Apple events. There are no accounts, in-app purchases, ads or analytics.

See [Apple's App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and [submission guidance](https://developer.apple.com/app-store/submitting/). Successful local checks do not establish App Store approval.
