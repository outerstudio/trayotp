.PHONY: build test strings app run release icon changelog clean

build:
	swift build

# Optimized builds: scrypt (Aegis vaults) takes ~40 s unoptimized vs ~0.1 s optimized.
# Real exports from other apps are fetched first; offline, those checks are skipped.
test:
	-Scripts/fetch-test-fixtures.sh
	swift run -c release OTPCoreTests

# Every translation has every string in Sources/, with the same format arguments.
strings:
	plutil -lint -s Support/Localizations/*.lproj/*.strings
	Scripts/extract-strings.py --check

app:
	CONFIG=release Scripts/bundle.sh

# Rebuild, quit the running copy, relaunch.
run: app
	-pkill -x TrayOTP
	@# Wait for it to exit, or LaunchServices sends the open to the dying process (error -600).
	@while pgrep -qx TrayOTP; do sleep 0.1; done
	open build/TrayOTP.app

release:
	CONFIG=release Scripts/bundle.sh

# Rewrite CHANGELOG.md from the Conventional Commits between release tags (user-facing changes only).
# Run after tagging a release. Needs Node.
changelog:
	npm ci --prefix Scripts/changelog --silent
	node Scripts/changelog/changelog.mjs file

# Redraw Support/AppIcon.icns after changing Scripts/make-icon.swift.
icon:
	swift Scripts/make-icon.swift

clean:
	rm -rf .build build
