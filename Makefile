WORKSPACE ?= CleverTapSDK.xcworkspace
TEST_SDK ?= 15.2
TEST_DEVICE ?= iPhone 11 Pro Max

XCARGS := -workspace $(WORKSPACE) \
					-sdk "iphonesimulator$(TEST_SDK)" \
					-destination "platform=iOS Simulator,OS=$(TEST_SDK),name=$(TEST_DEVICE)" \
					GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

build:
	set -o pipefail && xcodebuild $(XCARGS) -scheme CleverTapSDK build | xcpretty

format:
	clang-format -style=file -i CleverTapSDK/**/*.m CleverTapSDK/**/*.h && \
	clang-format -style=file -i ObjCStarter/**/*.m ObjCStarter/**/*.h

# we have to clean schemas independently because xcode does not allow to clean all schemes in a workspace
clean:
	xcodebuild $(XCARGS) -scheme CleverTapSDK clean | xcpretty && \
	xcodebuild $(XCARGS) -scheme ObjCStarter clean | xcpretty && \
	xcodebuild $(XCARGS) -scheme SwiftStarter clean | xcpretty

test: build
	set -o pipefail && xcodebuild $(XCARGS) -scheme CleverTapSDK test | xcpretty

examples: install-examples build-objc-example build-swift-example

install-examples: install build
	pod install --project-directory=ObjCStarter/
  pod install --project-directory=SwiftStarter/

build-objc-example: install-examples
	set -o pipefail && xcodebuild $(XCARGS) -scheme ObjCStarter clean build | xcpretty

build-swift-example: install-examples
	set -o pipefail && xcodebuild $(XCARGS) -scheme SwiftStarter clean build | xcpretty

install:
	pod install

prerequisites:
	.scripts/prerequisites.sh

oclint-examples: install-examples
	set -o pipefail && \
	xcodebuild -scheme ObjCStarter $(XCARGS) COMPILER_INDEX_STORE_ENABLE=NO clean build | xcpretty -r json-compilation-database --output compile_commands.json && \
	oclint-json-compilation-database -exclude Pods -exclude build -- -report-type xcode

oclint:
	set -o pipefail && \
	xcodebuild -scheme CleverTapSDK $(XCARGS) COMPILER_INDEX_STORE_ENABLE=NO clean build | xcpretty -r json-compilation-database --output compile_commands.json && \
	oclint-json-compilation-database -exclude Pods -exclude build -- -report-type xcode

swiftlint:
	Pods/SwiftLint/swiftlint lint --fix && Pods/SwiftLint/swiftlint lint --strict

podlint:
	pod lib lint --verbose

test-all: test examples oclint oclint-examples podlint
