SHELL := /bin/bash

PACKAGE ?= aws-foundation
XRD_DIR := apis/foundations
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
EXAMPLE_DEFAULT := examples/foundations/enterprise.yaml
RENDER_TESTS := $(wildcard tests/test-*)
E2E_TESTS := $(wildcard tests/e2etest-*)

# Examples list - mirrors GitHub Actions workflow
# Format: example_path::observed_resources_path (observed_resources_path is optional)
EXAMPLES := \
    examples/foundations/minimal.yaml:: \
    examples/foundations/individual.yaml:: \
    examples/foundations/individual.yaml::examples/test/mocks/observed-resources/individual/steps/1 \
    examples/foundations/enterprise.yaml:: \
    examples/foundations/enterprise.yaml::examples/test/mocks/observed-resources/enterprise/steps/1 \
    examples/foundations/import-existing.yaml:: \
    examples/foundations/with-networks.yaml:: \
    examples/foundations/with-ram-shares.yaml::

clean:
	rm -rf _output
	rm -rf .up

build:
	up project build

# Render all examples (parallel execution, output shown per-job when complete)
render\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Rendering $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example --observed-resources=$$observed; \
			else \
				echo "=== Rendering $$example ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Validate all examples (parallel execution, output shown per-job when complete)
validate\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Validating $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--observed-resources=$$observed --include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			else \
				echo "=== Validating $$example ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Shorthand aliases
render: render\:all
validate: validate\:all

# Single example render (usage: make render:minimal)
render\:%:
	@example="examples/foundations/$*.yaml"; \
	if [ -f "$$example" ]; then \
		echo "=== Rendering $$example ==="; \
		up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example; \
	else \
		echo "Example $$example not found"; \
		exit 1; \
	fi

# Single example validate (usage: make validate:minimal)
validate\:%:
	@example="examples/foundations/$*.yaml"; \
	if [ -f "$$example" ]; then \
		echo "=== Validating $$example ==="; \
		up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
			--include-full-xr --quiet | \
			crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
	else \
		echo "Example $$example not found"; \
		exit 1; \
	fi

test:
	up test run $(RENDER_TESTS)

e2e:
	up test run $(E2E_TESTS) --e2e

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)

generate-definitions:
	up xrd generate $(EXAMPLE_DEFAULT)

generate-function:
	up function generate --language=go-templating render $(COMPOSITION)
