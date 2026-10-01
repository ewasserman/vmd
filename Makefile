PREFIX ?= $(HOME)/.local
BUILD = .build/release
APP = dist/VMD.app

.PHONY: build test app run install clean

# SWIFT_FLAGS lets Homebrew pass --disable-sandbox (SPM's sandbox conflicts
# with Homebrew's build sandbox).
SWIFT_FLAGS ?=

build:
	swift build -c release $(SWIFT_FLAGS)

test:
	swift test

# Release version stamped into the app's Info.plist (VERSION=1.2.3). Homebrew
# passes it explicitly; local builds fall back to the latest git tag.
VERSION ?= $(shell git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//')

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Support/Info.plist $(APP)/Contents/Info.plist
	$(if $(VERSION),plutil -replace CFBundleShortVersionString -string $(VERSION) $(APP)/Contents/Info.plist)
	$(if $(VERSION),plutil -replace CFBundleVersion -string $(VERSION) $(APP)/Contents/Info.plist)
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	cp $(BUILD)/VMDApp $(APP)/Contents/MacOS/VMD
	cp -R $(BUILD)/vmd_VMDApp.bundle $(APP)/Contents/Resources/
	cp Support/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(APP)
	@echo "Built $(APP)"

run: app
	open $(APP)

install: app
	rm -rf /Applications/VMD.app
	cp -R $(APP) /Applications/VMD.app
	@echo "Installed /Applications/VMD.app"
	@install $(BUILD)/vmd $(PREFIX)/bin/vmd 2>/dev/null \
		&& echo "Installed $(PREFIX)/bin/vmd" \
		|| echo "Could not write $(PREFIX)/bin/vmd — run: sudo install $(BUILD)/vmd $(PREFIX)/bin/vmd"

clean:
	rm -rf .build dist
