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

.PHONY: all build bundle run clean

all: bundle

build:
	mkdir -p $(BUILD_DIR)
	$(SWIFTC) \
		$(SOURCES) \
		-o $(BUILD_DIR)/$(APP_NAME) \
		-framework AppKit \
		-framework Carbon \
		-framework CoreGraphics \
		-O \
		-whole-module-optimization

bundle: build
	rm -rf $(APP_BUNDLE_DIR)
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp Sources/ClipboardHistory/AppIcon.png $(RESOURCES_DIR)/
	cp $(BUILD_DIR)/$(APP_NAME) $(BINARY)
	cp Info.plist $(CONTENTS_DIR)/
	touch $(APP_BUNDLE_DIR)

run: bundle
	open $(APP_BUNDLE_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(APP_BUNDLE_DIR)