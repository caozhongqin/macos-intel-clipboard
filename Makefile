APP_NAME := Clipboard
BUNDLE_ID := com.cao.clipboard
SWIFTC := swiftc
SOURCES_DIR := Sources/ClipboardHistory
BUILD_DIR := .build
APP_BUNDLE_DIR := $(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
BINARY := $(MACOS_DIR)/$(APP_NAME)
SOURCES := $(wildcard $(SOURCES_DIR)/*.swift)
SIGN_IDENTITY := 3BAC4AC44F1E32F56362C93534BA4F188B4AEE5D

.PHONY: all bundle run clean

all: bundle

bundle: clean
	@echo "=== Building ==="
	mkdir -p $(BUILD_DIR)
	$(SWIFTC) \
		$(SOURCES) \
		-o $(BUILD_DIR)/$(APP_NAME) \
		-framework AppKit \
		-framework Carbon \
		-framework CoreGraphics \
		-O \
		-whole-module-optimization
	@echo "=== Creating app bundle ==="
	rm -rf $(APP_BUNDLE_DIR)
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp Sources/ClipboardHistory/AppIcon.png $(RESOURCES_DIR)/
	cp $(BUILD_DIR)/$(APP_NAME) $(BINARY)
	cp Info.plist $(CONTENTS_DIR)/
	@echo "=== Signing ==="
	codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE_DIR)"
	@echo "=== Done: $(APP_BUNDLE_DIR) is signed ==="

run: bundle
	open $(APP_BUNDLE_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(APP_BUNDLE_DIR)