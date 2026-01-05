# AGENTS.md - configuration-aws-foundation

This is a Crossplane XRD Configuration package for Foundation - a meta-composite that orchestrates Organization, IdentityCenter, and IPAM XRDs and creates Account ProviderConfigs.

## Important Notes

- Avoid Upbound-hosted configuration packages - they have paid-account restrictions. Favor `crossplane-contrib` packages.
- Target Crossplane 2+: don't set `deletionPolicy` on managed resources; use `managementPolicies` and defaults.

## Project Structure

```
apis/foundations/
  definition.yaml       # XRD definition
  composition.yaml      # Composition using Go templates
examples/foundations/
  individual.yaml       # Single-account setup (Identity Center + IPAM)
  enterprise.yaml       # Multi-account setup (Organization + all components)
  minimal.yaml          # Organization only
  import-existing.yaml  # Import existing resources
examples/observed-resources/
  enterprise/steps/1/   # Observed resources for multi-step rendering
functions/render/
  00-desired-values.yaml.gotmpl     # Extract spec values
  09-observed-values.yaml.gotmpl    # Check Ready conditions, resolve IDs
  10-organization.yaml.gotmpl       # Create Organization XRD
  20-identity-center.yaml.gotmpl    # Create IdentityCenter XRD
  30-ipam.yaml.gotmpl               # Create IPAM XRD
  40-account-providerconfigs.yaml.gotmpl  # Create ProviderConfigs per account
  99-status.yaml.gotmpl             # Surface status values
tests/
  e2etest-aws-foundation/           # E2E test (Identity Center + IPAM)
```

## Architecture

```
Foundation XR
├── Organization XRD (optional)
│   └── Creates: Organization, OUs, Accounts, Delegated Admins
├── IdentityCenter XRD (optional)
│   └── Creates: Groups, Users, Permission Sets, Account Assignments
├── IPAM XRD (optional)
│   └── Creates: IPAM, Pools
└── Account ProviderConfigs
    └── Creates: ProviderConfig per account (assumes OrganizationAccountAccessRole)
```

## Key Patterns

### Pass-Through Specs
The Foundation XRD uses `x-kubernetes-preserve-unknown-fields: true` to pass through the full specs of the underlying XRDs:
- `spec.organization` -> Organization XRD spec
- `spec.identityCenter` -> IdentityCenter XRD spec
- `spec.ipam` -> IPAM XRD spec

### Name-Based Resolution
Foundation resolves account and OU names to IDs for downstream resources:
- `spec.identityCenter.permissionSets[].assignToAccounts` - account names resolved to IDs
- `spec.ipam.delegatedAdminAccount` - account name resolved to ID

### Observed-State Gating
The composition waits for Organization to be Ready before creating resources that depend on account/OU IDs:
```go-template
{{ if and $accountReady (ne $accountId "Pending") }}
---
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: Object
...
{{ end }}
```

### Account ProviderConfigs
For each account in `spec.accounts`, Foundation creates a ProviderConfig that assumes `OrganizationAccountAccessRole` (AWS auto-creates this role when accounts are created via Organizations):
```yaml
spec:
  assumeRoleChain:
    - roleARN: arn:aws:iam::<account-id>:role/OrganizationAccountAccessRole
  credentials:
    source: PodIdentity
```

### Status Aggregation
Status is aggregated from all XRDs into a unified status:
```yaml
status:
  ready: true/false
  organization:
    organizationId: o-xxx
    rootId: r-xxx
  organizationalUnits:
    Security: ou-xxx
    Workloads/Prod: ou-yyy
  accounts:
    - name: acme-prod
      id: "123456789012"
      ready: true
  identityCenter:
    ready: true
  ipam:
    ready: true
    id: ipam-xxx
```

## Development Commands

```bash
make render-individual      # Render single-account example
make render-enterprise      # Render multi-account example
make render-minimal         # Render organization-only example
make render-enterprise-step-1  # Render with observed Organization ready
make test                   # Run KCL tests
make validate               # Validate compositions
make e2e                    # Run E2E tests
make build                  # Build package
```

## Dependencies

This configuration depends on:
- `ghcr.io/hops-ops/configuration-aws-organization`
- `ghcr.io/hops-ops/configuration-aws-identity-center`
- `ghcr.io/hops-ops/configuration-aws-ipam`
- `xpkg.crossplane.io/crossplane-contrib/function-auto-ready`
