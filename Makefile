APP_NAME = SuaveScroll
BUILD_DIR = .build/release
DIST = dist
APP = $(DIST)/$(APP_NAME).app

.PHONY: build bundle run dmg clean

build:
	swift build -c release

bundle: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Packaging/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"
	@echo "Built $(APP)"

run: bundle
	-pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	open "$(APP)"

# Drag-to-install disk image: SuaveScroll.app + an /Applications symlink.
dmg: bundle
	rm -rf "$(DIST)/dmg" "$(DIST)/$(APP_NAME).dmg"
	mkdir -p "$(DIST)/dmg"
	cp -R "$(APP)" "$(DIST)/dmg/"
	ln -s /Applications "$(DIST)/dmg/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DIST)/dmg" -ov -format UDZO "$(DIST)/$(APP_NAME).dmg"
	rm -rf "$(DIST)/dmg"
	@echo "Built $(DIST)/$(APP_NAME).dmg"

clean:
	rm -rf .build "$(DIST)"
