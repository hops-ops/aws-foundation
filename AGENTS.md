# AGENTS.md - configuration-aws-foundations

This is a Crossplane XRD Configuration package for Foundation - a meta-composite that orchestrates Organization, IdentityCenter, and IPAM composites.

## Important Notes

- Avoid Upbound-hosted configuration packages - they have paid-account restrictions. Favor `crossplane-contrib` packages.
- Target Crossplane 2+: don't set `deletionPolicy` on managed resources; use `managementPolicies` and defaults.

## Project Structure

```
apis/foundations/
  definition.yaml     # XRD definition
  composition.yaml    # Composition using Go templates
examples/foundations/
  example-standard.yaml   # Full example with all three composites
  example-minimal.yaml    # Minimal example with just Organization
functions/render/
  00-desired-values.yaml.gotmpl    # Extract spec values
  10-observed-values.yaml.gotmpl   # Check Ready conditions
  20-organization.yaml.gotmpl      # Create Organization composite
  30-identity-center.yaml.gotmpl   # Create IdentityCenter composite
  40-ipam.yaml.gotmpl              # Create IPAM composite
  99-status.yaml.gotmpl            # Surface status values
tests/
  # KCL-based tests
```

## Key Patterns

### Pass-Through Specs
The Foundation XRD uses `x-kubernetes-preserve-unknown-fields: true` to pass through the full specs of the underlying composites:
- `spec.organization` -> Organization composite spec
- `spec.identityCenter` -> IdentityCenter composite spec
- `spec.ipam` -> IPAM composite spec

### Observed-State Gating
The composition waits for the Organization to be Ready before creating IdentityCenter and IPAM composites:
```go-template
{{ if $organizationReady }}
---
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
...
{{ end }}
```

### Status Aggregation
Status is aggregated from all three composites into a unified status:
```yaml
status:
  ready: true/false  # All composites ready
  organization: { ... }
  identityCenter: { ... }
  ipam: { ... }
```

## Development Commands

```bash
make render-example-standard   # Render full example
make render-example-minimal    # Render minimal example
make test                      # Run KCL tests
make validate                  # Validate compositions
make build                     # Build package
```

## Dependencies

This configuration depends on:
- `ghcr.io/hops-ops/configuration-aws-organization`
- `ghcr.io/hops-ops/configuration-aws-identity-center`
- `ghcr.io/hops-ops/configuration-aws-ipam`
- `xpkg.crossplane.io/crossplane-contrib/function-auto-ready`
