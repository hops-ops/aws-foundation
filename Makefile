# Variables
XR_DIR = apis
XRM_NAME = foundations
XRM_COMPOSITION = $(XR_DIR)/$(XRM_NAME)/composition.yaml
XRM_API_DIR = $(XR_DIR)/$(XRM_NAME)
EXAMPLES_DIR = examples/$(XRM_NAME)
TESTS_DIR = tests
OUTPUT_DIR = _output
UP_DIR = .up

clean:
	rm -rf $(OUTPUT_DIR)
	rm -rf $(UP_DIR)

build:
	up project build

# Render examples
render: render-individual

render-all: render-individual render-enterprise render-import-existing render-minimal

render-example:
	@test -n "$(EXAMPLE_FILE)" || (echo "Please set EXAMPLE_FILE" >&2; exit 1)
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/$(EXAMPLE_FILE)

render-individual:
	$(MAKE) EXAMPLE_FILE=individual.yaml render-example

render-enterprise:
	$(MAKE) EXAMPLE_FILE=enterprise.yaml render-example

render-import-existing:
	$(MAKE) EXAMPLE_FILE=import-existing.yaml render-example

render-minimal:
	$(MAKE) EXAMPLE_FILE=minimal.yaml render-example

# Multi-step rendering with observed resources
# This composition uses XRDs (Organization, IdentityCenter, IPAM) which simplifies the reconciliation steps
#
# Step 1: Organization XRD ready (OUs and Accounts ready)
# This triggers: ProviderConfigs, IPAM XRD (with resolved account/OU IDs), IdentityCenter XRD assignments
render-enterprise-step-1:
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/enterprise.yaml \
		--observed-resources=examples/observed-resources/enterprise/steps/1/

# Render all enterprise steps
render-enterprise-all-steps: render-enterprise-step-1

# Tests
test:
	up test run $(TESTS_DIR)/*

# Validation
validate: validate-individual validate-enterprise validate-import-existing validate-minimal validate-example

validate-individual:
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/individual.yaml \
		--include-full-xr --quiet | crossplane beta validate $(XRM_API_DIR) -

validate-enterprise:
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/enterprise.yaml \
		--observed-resources=examples/observed-resources/enterprise/steps/1/ \
		--include-full-xr --quiet | crossplane beta validate $(XRM_API_DIR) -

validate-import-existing:
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/import-existing.yaml \
		--include-full-xr --quiet | crossplane beta validate $(XRM_API_DIR) -

validate-minimal:
	up composition render $(XRM_COMPOSITION) $(EXAMPLES_DIR)/minimal.yaml \
		--include-full-xr --quiet | crossplane beta validate $(XRM_API_DIR) -

validate-example:
	crossplane beta validate $(XRM_API_DIR) $(EXAMPLES_DIR)

# Publish
publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)

# Generate
generate-definitions:
	up xrd generate $(EXAMPLES_DIR)/enterprise.yaml

# E2E tests
e2e:
	up test run $(TESTS_DIR)/e2etest* --e2e

all: clean build render test validate
