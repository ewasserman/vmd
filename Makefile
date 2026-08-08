PREFIX ?= /usr/local
BUILD = .build/release
APP = dist/VMD.app

.PHONY: build test app run install clean

build:
	swift build -c release

test:
	swift test

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Support/Info.plist $(APP)/Contents/Info.plist
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	cp $(BUILD)/VMD $(APP)/Contents/MacOS/VMD
	cp -R $(BUILD)/vmd_VMDApp.bundle $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)
	@echo "Built $(APP)"

run: app
	open $(APP)

install: app
	rm -rf /Applications/VMD.app
	cp -R $(APP) /Applications/VMD.app
	install $(BUILD)/vmd $(PREFIX)/bin/vmd
	@echo "Installed /Applications/VMD.app and $(PREFIX)/bin/vmd"

clean:
	rm -rf .build dist
