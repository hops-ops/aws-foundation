# aws-foundation: $state Refactor Plan

## Current State Analysis

### Template Structure
```
functions/render/
├── 00-desired-values.yaml.gotmpl   # Spec extraction → scattered global vars
├── 09-observed-values.yaml.gotmpl  # Observed extraction → scattered global vars
├── 10-organization.yaml.gotmpl
├── 20-identity-center.yaml.gotmpl
├── 30-ipam.yaml.gotmpl
├── 40-account-providerconfigs.yaml.gotmpl
├── 50-networks.yaml.gotmpl
└── 99-status.yaml.gotmpl
```

### Problems with Current Approach
1. **Scattered variables** - `$organizationReady`, `$ouPathToId`, `$ipamPoolIdByName`, etc. pollute global namespace
2. **No clear interface** - Resource templates use a mix of spec-derived and observed variables
3. **Hard to reason about** - Which variables are available where? What depends on what?

---

## Proposed Pattern: Single $state Namespace

One `$state` object with clear structure. Each file manages its slice.

### $state Structure

```
$state
├── spec
│   ├── raw                 # exactly what user provided (no defaults)
│   └── effective           # with defaults applied (use this in templates)
│       ├── aws
│       ├── organization
│       ├── identityCenter
│       ├── ipam
│       └── networks
├── observed                # (01-04) from atProvider/XRD status
│   ├── organization
│   │   ├── ready
│   │   ├── id
│   │   ├── accounts []
│   │   └── ous {}
│   ├── identityCenter
│   ├── ipam
│   └── networks
└── foundation              # (05-08) computed state for this XRD
    ├── name
    ├── region
    ├── providerConfig
    ├── tags
    ├── managementPolicies
    ├── organization
    │   ├── render          # each slice has its own render flag
    │   ├── accountsByName
    │   └── ousWithAccounts
    ├── identityCenter
    │   ├── render
    │   └── ...
    ├── ipam
    │   ├── render
    │   └── poolsByName
    └── networks
        ├── render
        └── processed []
```

---

## File Structure

```
functions/render/
├── 00-state-init.yaml.gotmpl                    # Initialize $state with spec
│
├── 01-state-observed-organization.yaml.gotmpl   # $state.observed.organization
├── 02-state-observed-identity-center.yaml.gotmpl
├── 03-state-observed-ipam.yaml.gotmpl
├── 04-state-observed-networks.yaml.gotmpl
│
├── 05-state-foundation.yaml.gotmpl              # $state.foundation core (name, region, tags)
├── 06-state-foundation-organization.yaml.gotmpl # $state.foundation.organization + render
├── 07-state-foundation-identity-center.yaml.gotmpl
├── 08-state-foundation-ipam.yaml.gotmpl
├── 09-state-foundation-networks.yaml.gotmpl
│
├── 10-organization.yaml.gotmpl                  # if $state.foundation.organization.render
├── 20-identity-center.yaml.gotmpl
├── 30-ipam.yaml.gotmpl
├── 40-account-providerconfigs.yaml.gotmpl
├── 50-networks.yaml.gotmpl
└── 99-status.yaml.gotmpl                        # Uses $state.observed.* for status
```

---

## Implementation Examples

### 00-state-init.yaml.gotmpl

```yaml
{{- $xr := getCompositeResource . }}
{{- $metadata := $xr.metadata }}
{{- $spec := $xr.spec }}

# Initialize $state with raw spec and effective spec (with defaults)
{{- $state := dict
  "spec" (dict
    "raw" $spec
    "effective" (dict
      "name" ($metadata.name | default "foundation")
      "managementPolicies" ($spec.managementPolicies | default (list "*"))
      "aws" (dict
        "providerConfig" (($spec.aws | default dict).providerConfig | default "default")
        "region" (($spec.aws | default dict).region | default "us-east-1")
      )
      "k8s" (dict
        "providerConfig" (($spec.k8s | default dict).providerConfig | default "default")
      )
      "tags" (merge (dict "hops" "true") ($spec.tags | default dict))
      "organization" ($spec.organization | default dict)
      "organizationalUnits" ($spec.organizationalUnits | default list)
      "accounts" ($spec.accounts | default list)
      "delegatedAdministrators" ($spec.delegatedAdministrators | default list)
      "identityCenter" ($spec.identityCenter | default dict)
      "ipam" ($spec.ipam | default dict)
      "networks" ($spec.networks | default list)
      "networkDefaults" ($spec.networkDefaults | default dict)
      "memberAccountsProviderConfigs" ($spec.memberAccountsProviderConfigs | default dict)
    )
  )
  "observed" (dict)
  "foundation" (dict)
}}
```

### 01-state-observed-organization.yaml.gotmpl

```yaml
{{- $raw := $.observed.resources | default dict }}
{{- $entry := get $raw "organization" | default dict }}
{{- $resource := $entry.resource | default dict }}
{{- $status := $resource.status | default dict }}

# Check readiness
{{- $ready := false }}
{{- range ($status.conditions | default list) }}
  {{- if and (eq .type "Ready") (eq .status "True") }}
    {{- $ready = true }}
  {{- end }}
{{- end }}

# Build accounts list with ready status
{{- $accounts := list }}
{{- $allAccountsReady := true }}
{{- range ($status.accounts | default list) }}
  {{- $accounts = append $accounts . }}
  {{- if not (.ready | default false) }}
    {{- $allAccountsReady = false }}
  {{- end }}
{{- end }}

# Set observed.organization slice
{{- $observed := merge $state.observed (dict "organization" (dict
  "ready" $ready
  "allAccountsReady" $allAccountsReady
  "id" ($status.organizationId | default "Pending")
  "managementAccountId" ($status.managementAccountId | default "Pending")
  "rootId" ($status.rootId | default "Pending")
  "ous" ($status.organizationalUnits | default dict)
  "accounts" $accounts
)) }}
{{- $state = set $state "observed" $observed }}
```

### 05-state-foundation.yaml.gotmpl

```yaml
# Core foundation state - shared by all resources
# Always use spec.effective for values (defaults applied)
{{- $eff := $state.spec.effective }}

{{- $foundation := dict
  "name" $eff.name
  "region" $eff.aws.region
  "providerConfig" (dict
    "name" $eff.aws.providerConfig
    "kind" "ProviderConfig"
  )
  "k8sProviderConfig" (dict
    "name" $eff.k8s.providerConfig
    "kind" "ProviderConfig"
  )
  "tags" $eff.tags
  "managementPolicies" $eff.managementPolicies
}}
{{- $state = set $state "foundation" $foundation }}
```

### 06-state-foundation-organization.yaml.gotmpl

```yaml
{{- $eff := $state.spec.effective }}

# Determine if organization should render
{{- $ous := $eff.organizationalUnits }}
{{- $accounts := $eff.accounts }}
{{- $delegatedAdmins := $eff.delegatedAdministrators }}
{{- $render := or (gt (len $ous) 0) (gt (len $accounts) 0) (gt (len $delegatedAdmins) 0) }}

# Build account lookup: name -> config
{{- $accountsByName := dict }}
{{- range $accounts }}
  {{- $accountsByName = set $accountsByName .name . }}
{{- end }}

# Build account ID lookup from observed: name -> id
{{- $accountNameToId := dict }}
{{- $accountNameReady := dict }}
{{- range $state.observed.organization.accounts }}
  {{- $accountNameToId = set $accountNameToId .name (.id | default "Pending") }}
  {{- $accountNameReady = set $accountNameReady .name (.ready | default false) }}
{{- end }}

# Build OUs with nested accounts for Organization XRD
{{- $ousWithAccounts := list }}
{{- range $ou := $ous }}
  {{- $ouAccounts := list }}
  {{- range $account := $accounts }}
    {{- if eq ($account.ou | default "") $ou.path }}
      {{- $ouAccounts = append $ouAccounts $account }}
    {{- end }}
  {{- end }}
  {{- $ousWithAccounts = append $ousWithAccounts (merge $ou (dict "accounts" $ouAccounts)) }}
{{- end }}

# Set foundation.organization slice
{{- $org := dict
  "render" $render
  "managementPolicies" ($eff.organization.managementPolicies | default $state.foundation.managementPolicies)
  "accountsByName" $accountsByName
  "accountNameToId" $accountNameToId
  "accountNameReady" $accountNameReady
  "ousWithAccounts" $ousWithAccounts
}}
{{- $state = set $state "foundation" (merge $state.foundation (dict "organization" $org)) }}
```

### 10-organization.yaml.gotmpl

```yaml
{{- if $state.foundation.organization.render }}
{{- $eff := $state.spec.effective }}
---
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Organization
metadata:
  name: {{ $state.foundation.name }}
  annotations:
    {{ setResourceNameAnnotation "organization" }}
spec:
  managementPolicies: {{ $state.foundation.organization.managementPolicies | toJson }}
  providerConfigRef:
    name: {{ $state.foundation.providerConfig.name }}
    kind: {{ $state.foundation.providerConfig.kind }}
  tags: {{ $state.foundation.tags | toYaml | nindent 4 }}
  organization:
    managementPolicies: {{ $state.foundation.organization.managementPolicies | toJson }}
    awsServiceAccessPrincipals: {{ $eff.organization.awsServiceAccessPrincipals | default list | toJson }}
    {{- if $eff.organization.externalName }}
    externalName: {{ $eff.organization.externalName }}
    {{- end }}
  organizationalUnits: {{ $state.foundation.organization.ousWithAccounts | toYaml | nindent 4 }}
  delegatedAdministrators: {{ $eff.delegatedAdministrators | toYaml | nindent 4 }}
{{- end }}
```

### 99-status.yaml.gotmpl

```yaml
---
apiVersion: {{ $xr.apiVersion }}
kind: {{ $xr.kind }}
status:
  {{- $orgObs := $state.observed.organization }}
  {{- $ipamObs := $state.observed.ipam }}

  # Overall ready: org ready (if enabled) or ipam ready (if no org) or true
  {{- $ready := true }}
  {{- if $state.foundation.organization.render }}
    {{- $ready = and $orgObs.ready $orgObs.allAccountsReady }}
  {{- else if $state.foundation.ipam.render }}
    {{- $ready = $ipamObs.ready }}
  {{- end }}
  ready: {{ $ready }}

  # Expose spec for debugging - user sees what they provided vs what's used
  spec:
    raw:
      {{- $state.spec.raw | toYaml | nindent 6 }}
    effective:
      {{- $state.spec.effective | toYaml | nindent 6 }}

  {{- if $state.foundation.organization.render }}
  organization:
    ready: {{ $orgObs.ready }}
    organizationId: {{ $orgObs.id }}
    managementAccountId: {{ $orgObs.managementAccountId }}
    rootId: {{ $orgObs.rootId }}
  {{- end }}

  # ... rest of status uses $state.observed.*
```

This allows users to run `kubectl get foundation my-foundation -o yaml` and immediately see:
- What they actually provided in their spec (`status.spec.raw`)
- What defaults were applied (`status.spec.effective`)

Example output:
```yaml
status:
  ready: true
  spec:
    raw:
      aws:
        region: us-east-1
      accounts:
        - name: dev
          email: dev@example.com
    effective:
      aws:
        region: us-east-1
        providerConfig: default      # defaulted!
      tags:
        hops: "true"                 # defaulted!
      managementPolicies: ["*"]      # defaulted!
      accounts:
        - name: dev
          email: dev@example.com
  organization:
    ready: true
    # ...
```

---

## Benefits

1. **Single namespace** - Just `$state`, no separate `$observed`
2. **Clear structure** - `spec.raw`, `spec.effective`, `observed`, `foundation` are distinct concerns
3. **Co-located render flags** - Each slice decides if it should render
4. **Self-documenting** - `$state.foundation.organization.accountsByName` is clear
5. **Nested structure** - Networks under foundation because they're part of foundation
6. **Debuggable** - Status exposes `spec.raw` vs `spec.effective` so users see defaults applied

---

## Unit Test Improvements

### Current Issues
- Most tests use `xrPath:` referencing `examples/` folder
- Tests assert full resource structures
- Coupling between tests and example files

### Proposed Approach
- Inline `xr:` fixtures for each test
- Minimal fixtures with only fields relevant to test
- Focused assertions on specific behaviors

### Example Tests

```kcl
# Test: Organization disabled when no OUs/accounts
metav1alpha1.CompositionTest{
    metadata.name: "test-org-disabled-when-empty"
    spec = {
        compositionPath: "apis/foundations/composition.yaml"
        xrdPath: "apis/foundations/definition.yaml"
        xr: {
            apiVersion: "aws.hops.ops.com.ai/v1alpha1"
            kind: "Foundation"
            metadata.name: "test"
            spec.aws.region: "us-east-1"
            # No organizationalUnits, no accounts
        }
        assertResources: []  # Organization should NOT render
    }
}

# Test: Organization enabled when accounts present
metav1alpha1.CompositionTest{
    metadata.name: "test-org-enabled-with-accounts"
    spec = {
        compositionPath: "apis/foundations/composition.yaml"
        xrdPath: "apis/foundations/definition.yaml"
        xr: {
            apiVersion: "aws.hops.ops.com.ai/v1alpha1"
            kind: "Foundation"
            metadata.name: "test"
            spec = {
                aws.region: "us-east-1"
                accounts: [{name: "dev", email: "dev@example.com"}]
            }
        }
        assertResources: [
            {kind: "Organization", metadata.name: "test"}
        ]
    }
}

# Test: Default tags include hops=true
metav1alpha1.CompositionTest{
    metadata.name: "test-default-tags"
    spec = {
        compositionPath: "apis/foundations/composition.yaml"
        xrdPath: "apis/foundations/definition.yaml"
        xr: {
            apiVersion: "aws.hops.ops.com.ai/v1alpha1"
            kind: "Foundation"
            metadata.name: "test"
            spec = {
                aws.region: "us-east-1"
                accounts: [{name: "dev", email: "dev@example.com"}]
            }
        }
        assertResources: [
            {kind: "Organization", spec.tags.hops: "true"}
        ]
    }
}
```

---

## Implementation Order

1. ✅ Document refined pattern (this file)
2. ⬜ Update skill documentation with new pattern
3. ⬜ Refactor aws-foundation templates
4. ⬜ Update unit tests to use inline fixtures
5. ⬜ Validate with `make render:all && make validate:all && make test`
