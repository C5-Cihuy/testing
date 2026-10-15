# Repository guidance

## Xcode setup and verification
- `project.yml` is the main entry point and source of truth for Xcode-related project setup (targets, source membership, dependencies, settings, and schemes). Change it rather than only editing `Testing.xcodeproj`; regenerate with `xcodegen generate --spec project.yml`.
- Use Xcode 26 / Swift tools 6.2 or newer: the app targets iOS 26 and the local package requires Swift tools 6.2. The app uses Swift 5 language mode with default `MainActor` isolation and approachable concurrency; the package has its own settings.
- Simulator build from the repository root: `xcodebuild -project Testing.xcodeproj -scheme Testing -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build`.
- No test targets are configured: the `Testing` scheme has no testables and the local package has no `.testTarget`. Add the appropriate target before attempting test or single-test commands.

## App boundaries and conventions
- App startup is `Testing/App/MyApp.swift` → `RootRouterView` → `HomeView`. `RootRouterView` owns and injects `AppRouter`; extend the route enums and centralized destinations for navigation and modal flows.
- `SharedContent` is compiled directly into the app, not a separate package. `project.yml` deliberately excludes the deferred networking extension, command, view model, previews, and client/server views; do not assume those files are active or remove the exclusions incidentally.
- Use `AppColors` as the color system, defined in `SharedContent/Extenstions/AppColors.swift` (the directory spelling is intentional here). Semantic colors and foreground pairs map to assets in `SharedContent/Resources/Assets.xcassets`; avoid ad hoc UI colors.
- Use the repository's Swift pattern skills to keep code maintainable: `swift-test-pattern`, `swiftui-mvvm-pattern`, `swiftui-components-pattern`, and `swiftui-router-pattern`. Load the relevant skill under `.agents/skills/` before writing tests, features, reusable components, or navigation; do not duplicate their detailed guidance here.
- Register new persistent model types in `SharedContent/Systems/DataBase.swift`; its explicit list defines the schema passed to `PersistenceStack`.
- `Packages/PeerToPeerMessaging` is a local package copied from an upstream sample; provenance and licensing are in its README and LICENSE. Linking it does not start networking. Configure Bonjour services and the local-network usage description in `project.yml` before enabling discovery or messaging.

## Repository workflows
- For GitHub MCP credentials, set `GITHUB_PERSONAL_ACCESS_TOKEN` in `.env.local` and launch with `bash .opencode/run.sh`. The wrapper exports the environment and uses a standalone server because a shared background server does not inherit those variables.
- Before branch/PR operations or issue management, load `.agents/skills/branching-strategy` or `.agents/skills/issue-management`, respectively; repository-specific hierarchy and templates live there.

## Shared skills
- `.agents/skills/` is the canonical skill directory. `.claude/skills` and `.opencode/skills` are relative symlinks to it; edit the canonical files rather than creating tool-specific copies.
- Use the coding tool's native skill loader when available. Otherwise, read the relevant `SKILL.md` and follow its instructions, resolving bundled references and templates relative to that skill's directory.
- Skills share workflow guidance, not tool configuration or credentials. GitHub workflows still require a configured GitHub MCP server; discover the available operations rather than assuming tool names match across clients.
