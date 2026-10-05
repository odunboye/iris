.PHONY: counter-check build test browser-test check release-check native-check docs-check docs-test docs-integration examples-setup examples-check clean

build:
	idris2 --build iris.ipkg

test: build
	idris2 --install iris.ipkg
	cd tests && idris2 -p iris PublicAPITest.idr -o public-api-tests
	cd tests && idris2 -p iris LegacyAPITest.idr -o legacy-api-tests
	cd tests && idris2 -p iris EventWireTest.idr -o event-wire-tests
	cd tests && idris2 -p iris RuntimeTest.idr -o runtime-tests
	cd tests && idris2 -p contrib -p iris TerminalRuntimeTest.idr -o terminal-runtime-tests
	cd tests && idris2 -p iris CanvasLayoutTest.idr -o canvas-layout-tests
	cd tests && idris2 -p iris RouterTest.idr -o router-tests
	cd tests && idris2 -p iris DOMRenderTest.idr -o dom-render-tests
	cd tests && idris2 -p iris HttpTest.idr -o http-tests
	./tests/build/exec/public-api-tests
	./tests/build/exec/legacy-api-tests
	./tests/build/exec/event-wire-tests
	./tests/build/exec/runtime-tests
	./tests/build/exec/terminal-runtime-tests
	./tests/build/exec/canvas-layout-tests
	./tests/build/exec/router-tests
	./tests/build/exec/dom-render-tests
	./tests/build/exec/http-tests

browser-test:
	npm run test:browser

counter-check:
	idris2 --cg javascript --build examples/form/web.ipkg
	idris2 --cg javascript --build examples/form/canvas.ipkg
	idris2 --build examples/form/terminal.ipkg
	idris2 --cg javascript --build tests/keyed-dom.ipkg
	idris2 --build tests/terminal-lifecycle.ipkg
	idris2 --cg javascript --build tests/canvas-lifecycle.ipkg
	idris2 --build examples/counter/terminal.ipkg
	idris2 --cg javascript --build examples/counter/web.ipkg
	idris2 --cg javascript --build examples/counter/canvas.ipkg
	node --check examples/counter/build/exec/counter-web
	node --check examples/counter/build/exec/counter-canvas

# Run setup explicitly once; check itself never obtains mobile tooling.
CAPACITOR ?= ../capacitor
examples-setup:
	PYTHONDONTWRITEBYTECODE=1 python3 scripts/setup-examples.py --capacitor "$(CAPACITOR)"

examples-check:
	idris2 --cg javascript --build examples/router/web.ipkg
	idris2 --cg javascript --build examples/client/web.ipkg
	idris2 --cg javascript --build examples/mobile-commands/web.ipkg
	idris2 --cg javascript --build examples/hot-reload/v1.ipkg
	idris2 --cg javascript --build examples/hot-reload/v2.ipkg
	idris2 --cg javascript --build examples/theme/web.ipkg

# Explicit end-to-end Pack/mobile CLI check; may download dependencies.
docs-integration: docs-check
	PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-docs.py --mobile-cli

docs-check:
	PYTHONDONTWRITEBYTECODE=1 python3 scripts/check-docs.py
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts -p test_check_docs.py

docs-test: docs-check
	PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-docs.py

check: test counter-check
	cd tests && idris2 --cg node -p iris PublicAPITest.idr -o public-api-node
	node ./tests/build/exec/public-api-node
	$(MAKE) -C examples/todo check
	./scripts/validate-release.sh
	$(MAKE) examples-check docs-test

release-check:
	$(MAKE) -C examples/todo check
	./scripts/validate-release.sh

native-check:
	./scripts/validate-native.sh all

clean:
	rm -rf build tests/build
	$(MAKE) -C examples/todo clean
