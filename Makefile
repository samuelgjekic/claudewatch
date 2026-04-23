.PHONY: build run bundle install uninstall clean

APP_NAME = ClaudeWatch
BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app

build:
	swift build -c release

run:
	swift run

bundle: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	@echo "Built $(APP_BUNDLE)"

install: bundle
	@cp -r "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

uninstall:
	@rm -rf "/Applications/$(APP_NAME).app"
	@echo "Removed /Applications/$(APP_NAME).app"

clean:
	@rm -rf .build build
	@echo "Cleaned build artifacts"
