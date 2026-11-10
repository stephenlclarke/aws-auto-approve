SWIFT ?= $(shell xcrun --toolchain XcodeDefault --find swift)
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/module-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache

.PHONY: all build build-release test unit-test coverage bundle install run clean lint sonar
all: test bundle
build:
	$(SWIFT) build --disable-sandbox -Xswiftc -warnings-as-errors
build-release:
	$(SWIFT) build --disable-sandbox -c release -Xswiftc -warnings-as-errors
unit-test:
	bash Tests/Shell/change-scope.sh
	bash Tests/Shell/login.sh
	$(SWIFT) test --disable-sandbox --filter ApprovalCoreTests.ApprovalCoreTests
test:
	bash Tests/Shell/change-scope.sh
	bash Tests/Shell/login.sh
	$(SWIFT) test --disable-sandbox --enable-code-coverage
coverage: test
	$(SWIFT) Tools/coverage.swift
bundle: build-release
	bash Tools/bundle.sh
install: bundle
	bash Tools/install.sh
run: build
	.build/debug/aws-auto-approve $(ARGS)
clean:
	$(SWIFT) package clean
	rm -rf dist coverage.xml
lint:
	markdownlint '*.md' 'docs/**/*.md'
	actionlint
	bash -n Tools/bundle.sh Tools/build-icon.sh Tools/install.sh Integration/aws-auto-approve-login Tests/Shell/login.sh Tests/Shell/change-scope.sh .github/actions/change-scope/check.sh
	zsh -n Completions/*
sonar:
	sonar-scanner -Dsonar.projectVersion=$$(git rev-parse HEAD)
