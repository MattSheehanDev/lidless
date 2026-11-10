.PHONY: app run install test package clean

# Command Line Tools builds lose the Swift Testing macro plugin on incremental rebuilds.
CLT_DIR := /Library/Developer/CommandLineTools
CLT_TESTING_PLUGINS := $(CLT_DIR)/usr/lib/swift/host/plugins/testing
TEST_FLAGS := $(if $(filter $(CLT_DIR),$(shell xcode-select -p 2>/dev/null)),-Xswiftc -plugin-path -Xswiftc $(CLT_TESTING_PLUGINS))

test:
	swift test $(TEST_FLAGS)

app:
	./scripts/bundle.sh

run: app
	open build/Lidless.app

install: app
	rm -rf /Applications/Lidless.app
	cp -R build/Lidless.app /Applications/
	open /Applications/Lidless.app

# make package VERSION=1.2.0
package:
	@test -n "$(VERSION)" || (echo "usage: make package VERSION=x.y.z" && exit 1)
	./scripts/package.sh $(VERSION)
clean:
	rm -rf .build build
