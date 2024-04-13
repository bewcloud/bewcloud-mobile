.PHONY: start
start:
	flutter run

.PHONY: format
format:
	dart format lib

.PHONY: test
test:
	flutter test

.PHONY: build/android
build/android:
	flutter build apk --split-per-abi --release

.PHONY: build/ios
build/ios:
	flutter build ios --release && flutter build ipa --export-method development

.PHONY: install
install:
	flutter install
