NAME := SYSTORE
SCHEME := Feather
PLATFORMS := iphoneos maccatalyst

TMP := $(TMPDIR)/$(NAME)
CERT_JSON_URL := https://backloop.dev/pack.json

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
	rm -rf $(TMP)
	rm -rf packages
	rm -rf Payload
	rm -rf _build

deps:
	rm -rf deps || true
	mkdir -p deps

	curl -fsSL "$(CERT_JSON_URL)" -o cert.json
	jq -r '.cert' cert.json > deps/server.crt
	jq -r '.key1, .key2' cert.json > deps/server.pem
	jq -r '.info.domains.commonName' cert.json > deps/commonName.txt


$(PLATFORMS): deps
	rm -rf _build

	@if [ "$@" = "iphoneos" ]; then \
		DEST="generic/platform=iOS"; \
	else \
		DEST="generic/platform=macOS,variant=Mac Catalyst"; \
	fi; \
	xcodebuild \
		-project Feather.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-derivedDataPath $(TMP)/$@ \
		-skipPackagePluginValidation \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO \
		IPHONEOS_DEPLOYMENT_TARGET=15.0

	mkdir -p _build/Payload
	# 🔥 السر هنا: نسخ التطبيق كما هو بدون تغيير اسمه الداخلي لتجنب تلف التوقيع
	cp -R $(TMP)/$@/Build/Products/Release-*/*.app _build/Payload/
	chmod -R 0755 _build/Payload/*.app
	codesign --force --sign - --timestamp=none _build/Payload/*.app
	cp deps/* _build/Payload/*.app/ || true

	mkdir -p packages

	@if [ "$@" = "iphoneos" ]; then \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/$(NAME).ipa"; \
	else \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload/*.app "packages/$(NAME)_Catalyst.zip"; \
	fi
