.PHONY: run package test

run:
	swift run MochiCorner

package:
	./scripts/package_app.sh

test:
	swift test
