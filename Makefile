.PHONY: icon generate build test clean

SIM ?= iPhone 16

icon:
	python3 scripts/make-icon.py

generate:
	xcodegen generate --spec project.yml

build: generate
	./scripts/build-ipa.sh

test: generate
	xcodebuild test \
		-project Keys.xcodeproj \
		-scheme Keys \
		-destination "platform=iOS Simulator,name=$(SIM)" \
		-derivedDataPath build/DerivedData \
		CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf build Keys.xcodeproj