.PHONY: help build test app run release publish icon clean

help: ## Show targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-10s %s\n", $$1, $$2}'

build: ## Debug build of the package
	swift build

test: ## Unit tests
	swift test

app: ## Build build/W-Player.app
	scripts/build-app.sh

run: app ## Build and open the app
	open build/W-Player.app

release: ## Disk image of the app in releases/v<VERSION>/
	scripts/release.sh

publish: ## release + create the GitHub release
	scripts/release.sh --publish

icon: ## Redraw the app icon
	swift scripts/make-icon.swift build/AppIcon.icns

clean:
	rm -rf .build build
