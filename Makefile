.PHONY: app run install test release clean

# Command Line Tools builds lose the Swift Testing macro plugin on incremental rebuilds.
CLT_TESTING_PLUGINS := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
TEST_FLAGS := $(if $(wildcard $(CLT_TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(CLT_TESTING_PLUGINS))

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

# make release VERSION=1.2.0
release:
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=x.y.z" && exit 1)
	./scripts/release.sh $(VERSION)

clean:
	rm -rf .build build
