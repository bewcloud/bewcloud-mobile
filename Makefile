.PHONY: start
start:
	flutter run

.PHONY: format
format:
	dart format lib

.PHONY: test
test:
	flutter test

.PHONY: build
build:
	flutter build apk --split-per-abi --release
