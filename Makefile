.PHONY: build test app run release icon clean

build:
	swift build

# Optimized builds: scrypt (Aegis vaults) takes ~40 s unoptimized vs ~0.1 s optimized.
# Real exports from other apps are fetched first; offline, those checks are skipped.
test:
	-Scripts/fetch-test-fixtures.sh
	swift run -c release OTPCoreTests

app:
	CONFIG=release Scripts/bundle.sh

# Rebuild, quit the running copy, relaunch.
run: app
	-pkill -x TrayOTP
	open build/TrayOTP.app

release:
	CONFIG=release Scripts/bundle.sh

# Redraw Support/AppIcon.icns after changing Scripts/make-icon.swift.
icon:
	swift Scripts/make-icon.swift

clean:
	rm -rf .build build
