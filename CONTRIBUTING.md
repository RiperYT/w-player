# Contributing

Thanks for helping.

1. Open an issue first for anything bigger than a bug fix, so we can agree on the approach.
2. Keep pull requests small and focused. Add a test when the logic can be tested without the UI (most can, see
   `Tests/WPlayerCoreTests`).
3. Say which Mac and macOS version you tested on.
4. Run `make test` before you push.
5. No new network calls, analytics or accounts (the update check is the only one).
6. Changes to how W-Player edits macOS's wallpaper manifest need a test in `AerialsManifestTests`: a broken manifest
   hides every video wallpaper on the Mac.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org): `feat(core): …`,
`fix(app): …`, `docs: …`, `test: …`, `chore: …`.

By sending a pull request you agree that your contribution is licensed under the Apache License 2.0.
