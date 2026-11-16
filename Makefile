SWIFT ?= $(shell xcrun --toolchain XcodeDefault --find swift)
RELEASE_ARCH_FLAGS = $(if $(BUILD_ARCH),--arch $(BUILD_ARCH),)
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/module-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache

.PHONY: all build build-release test unit-test coverage bundle install configure run clean lint sonar resolve test-asan test-tsan
all: test bundle
resolve:
	$(SWIFT) package --disable-sandbox resolve
build:
	$(SWIFT) build --disable-sandbox -Xswiftc -warnings-as-errors
build-release:
	$(SWIFT) build --disable-sandbox -c release $(RELEASE_ARCH_FLAGS) -Xswiftc -warnings-as-errors
unit-test:
	bash Tests/Shell/ci-signing.sh
	bash Tests/Shell/notarise.sh
	bash Tests/Shell/change-scope.sh
	bash Tests/Shell/login.sh
	bash Tests/Shell/configure.sh
	$(SWIFT) test --disable-sandbox --filter ApprovalCoreTests.ApprovalCoreTests
test:
	bash Tests/Shell/ci-signing.sh
	bash Tests/Shell/notarise.sh
	bash Tests/Shell/change-scope.sh
	bash Tests/Shell/login.sh
	bash Tests/Shell/configure.sh
	$(SWIFT) test --disable-sandbox --enable-code-coverage
test-asan:
	$(SWIFT) test --disable-sandbox --scratch-path .build/asan --sanitize address
test-tsan:
	$(SWIFT) test --disable-sandbox --scratch-path .build/tsan --sanitize thread
coverage: test
	$(SWIFT) Tools/coverage.swift
bundle: build-release
	bash Tools/bundle.sh
install: bundle
	bash Tools/install.sh
configure:
	bash configure.sh $(ARGS)
run: build
	.build/debug/aws-auto-approve $(ARGS)
clean:
	$(SWIFT) package clean
	rm -rf dist coverage.xml
lint:
	markdownlint '*.md' 'docs/**/*.md'
	actionlint
	bash -n configure.sh Tools/bundle.sh Tools/build-icon.sh Tools/install.sh Tools/package-release.sh Tools/notarise.sh Tools/ci-signing.sh Tools/release-ready.sh Tools/check-commit.sh Integration/aws-auto-approve-login Tests/Shell/login.sh Tests/Shell/change-scope.sh Tests/Shell/configure.sh Tests/Shell/notarise.sh Tests/Shell/ci-signing.sh .github/actions/change-scope/check.sh
	shellcheck -x configure.sh Tests/Shell/configure.sh Tests/Shell/notarise.sh Tests/Shell/ci-signing.sh Tools/package-release.sh Tools/notarise.sh Tools/ci-signing.sh Tools/release-ready.sh Tools/check-commit.sh
	zsh -n Completions/*
sonar:
	sonar-scanner -Dsonar.projectVersion=$$(git rev-parse HEAD)
