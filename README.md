# configuration-aws-foundation

Foundation provides a single resource to manage your entire AWS foundation, from solo developer to enterprise. Start simple and evolve as you grow.

## What Foundation Composes

Foundation is a unified API that composes three specialized XRDs:

| Component | Purpose | Documentation |
|-----------|---------|---------------|
| **[Organization](../aws-organization)** | AWS Organization, OUs, accounts, delegated administrators | Consolidated billing, SCPs, account factory |
| **[Identity Center](../aws-identity-center)** | SSO groups, users, permission sets, account assignments | Single sign-on, time-limited credentials, federation-ready |
| **[IPAM](../aws-ipam)** | IP address pools, automatic allocation, RAM sharing | No overlapping CIDRs, dual-stack IPv6, compliance tracking |

**Why one resource?**
- Account names are referenced everywhere and automatically resolved to AWS account IDs
- OU paths are resolved for IPAM RAM sharing
- Each account gets a ProviderConfig for cross-account access via `OrganizationAccountAccessRole`
- Single source of truth for your entire AWS foundation

## Prerequisites

**Identity Center must be enabled manually** (one-time setup):

1. Go to [IAM Identity Center console](https://console.aws.amazon.com/singlesignon)
2. Click **Enable** and choose **Enable with AWS Organizations**
3. Note the **Instance ARN** and **Identity Store ID** from Settings

These values are required in the `identityCenter` section of your Foundation spec.

## The Journey

### Stage 1: Individual Developer

You have one AWS account. You want SSO access and organized IP allocation for your VPCs.

**What you need:**
- Identity Center for SSO (stop using IAM users)
- IPAM with hierarchical pools (global → regional) for automatic VPC allocation

**Why Identity Center?**
- Federate with Google/Okta/Azure AD later without changing anything
- Time-limited credentials (no long-lived access keys)
- Single place to manage who has access to what

**Why IPAM with hierarchy?**
- Global pools define your address space, regional pools allocate from them
- Request CIDRs from pools instead of manually tracking ranges
- Dual-stack ready (IPv4 + IPv6) for modern workloads
- When you add regions or accounts later, VPCs won't overlap

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: my-foundation
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: default
    region: us-east-1

  # SSO access - get identityStoreId and instanceArn from AWS SSO console
  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: Administrators
        description: Full admin access

    permissionSets:
      - name: AdministratorAccess
        sessionDuration: PT4H  # 4 hour sessions
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess

  # IP address management - hierarchical pools for dual-stack networking
  ipam:
    region: us-east-1
    operatingRegions: [us-east-1]

    pools:
      # ═══════════════════════════════════════════════════════════
      # IPv4 Hierarchy: Global → Regional
      # ═══════════════════════════════════════════════════════════
      ipv4:
        # Global pool - top of hierarchy
        - name: ipv4-global
          cidr: 10.0.0.0/8  # 16 million addresses
          allocations:
            netmaskLength:
              default: 12  # Carve /12 per region

        # Regional pool - allocates from global
        - name: ipv4-us-east-1
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.0.0.0/12  # 10.0.0.0 - 10.15.255.255
          allocations:
            netmaskLength:
              default: 16  # /16 per VPC
              min: 16
              max: 24

      # ═══════════════════════════════════════════════════════════
      # IPv6 Pools
      # ═══════════════════════════════════════════════════════════
      ipv6:
        # ULA (private) pools - fd00::/8, not internet-routable
        ula:
          # Global ULA pool
          - name: ipv6-ula-global
            netmaskLength: 40  # AWS assigns from fd00::/8
            allocations:
              netmaskLength:
                default: 44  # Carve /44 per region

          # Regional ULA pool
          - name: ipv6-ula-us-east-1
            sourcePoolRef: ipv6-ula-global
            locale: us-east-1
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 48  # /48 per VPC
                min: 48
                max: 56

        # GUA (public) pools - Amazon-provided, internet-routable
        gua:
          - name: ipv6-gua-us-east-1
            locale: us-east-1
            netmaskLength: 52
            publicIpSource: amazon
            awsService: ec2
            allocations:
              netmaskLength:
                default: 56  # /56 per VPC
                min: 52
                max: 60
```

**Using the pools:** After Foundation is ready, use Network Allocation XRDs to reserve CIDRs from these pools, then create Networks with those allocations.

```yaml
# 1. Allocate IPv4 from regional pool
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv4NetworkAllocation
metadata:
  name: my-network
spec:
  regionalPoolId: <from-status.ipam.pools.ipv4[name=ipv4-us-east-1].id>
  scopeId: <from-status.ipam.privateDefaultScopeId>
---
# 2. Allocate IPv6 ULA from regional pool (optional)
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv6ULANetworkAllocation
metadata:
  name: my-network
spec:
  regionalPoolId: <from-status.ipam.pools.ipv6.ula[name=ipv6-ula-us-east-1].id>
  scopeId: <from-status.ipam.privateDefaultScopeId>
  region: us-east-1
---
# 3. Create Network using allocated CIDRs
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Network
metadata:
  name: my-network
spec:
  clusterName: my-cluster
  vpc:
    cidr: <from-ipv4-allocation-status.cidr>
    ipv6:
      ula:
        enabled: true
        cidr: <from-ipv6-ula-allocation-status.cidr>
      amazonProvided:
        enabled: true  # Also get public IPv6
  subnets: <from-allocation-status.subnets>
  aws:
    config:
      region: us-east-1
```

### Stage 2: Small Team

You're hiring. You need different access levels and maybe a separate dev environment.

**What changes:**
- Add groups for different roles (Developers, ReadOnly)
- Add more permission sets with appropriate policies
- Consider adding a second AWS account for dev/staging

```yaml
# Add to identityCenter section:
groups:
  - name: Administrators
    description: Full admin access
  - name: Developers
    description: Can deploy and debug, no IAM changes
  - name: ReadOnly
    description: View resources only

permissionSets:
  - name: AdministratorAccess
    sessionDuration: PT4H
    managedPolicies:
      - arn:aws:iam::aws:policy/AdministratorAccess

  - name: PowerUserAccess
    sessionDuration: PT8H  # Longer sessions for developers
    managedPolicies:
      - arn:aws:iam::aws:policy/PowerUserAccess

  - name: ViewOnlyAccess
    sessionDuration: PT1H
    managedPolicies:
      - arn:aws:iam::aws:policy/ViewOnlyAccess
```

### Stage 3: Multiple Accounts

You need environment isolation. Production shouldn't share an account with dev.

**What you need:**
- AWS Organization to create and manage accounts
- Organizational Units (OUs) for grouping accounts
- Permission sets assigned to specific accounts
- IPAM pools shared across accounts

**Why Organizations?**
- Consolidated billing
- Service Control Policies (SCPs) for guardrails
- Centralized Identity Center management
- Account factory - spin up new accounts in minutes

**Why OUs?**
- Apply policies to groups of accounts
- Share IPAM pools with entire OUs via RAM
- Logical grouping (Workloads/Prod vs Workloads/Dev)

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: acme
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: management-account
    region: us-east-1

  tags:
    organization: acme
    managed-by: crossplane

  # Enable AWS Organizations
  organization:
    awsServiceAccessPrincipals:
      - sso.amazonaws.com

  # Create OU hierarchy
  organizationalUnits:
    - path: Workloads
    - path: Workloads/Prod
    - path: Workloads/Dev

  # Create accounts in OUs
  accounts:
    - name: acme-prod
      email: aws-prod@acme.example.com
      ou: Workloads/Prod

    - name: acme-dev
      email: aws-dev@acme.example.com
      ou: Workloads/Dev

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: Administrators
      - name: Developers

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [Administrators]
        assignToAccounts: [acme-prod, acme-dev]  # Reference by name

      - name: PowerUserAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [Developers]
        assignToAccounts: [acme-dev]  # Developers only get dev access

  ipam:
    region: us-east-1
    operatingRegions: [us-east-1]

    pools:
      ipv4:
        # Global pool - top of hierarchy
        - name: ipv4-global
          cidr: 10.0.0.0/8
          allocations:
            netmaskLength:
              default: 12

        # Regional pool - allocates from global
        - name: ipv4-us-east-1
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.0.0.0/12
          allocations:
            netmaskLength:
              default: 16

      ipv6:
        ula:
          # Global ULA pool
          - name: ipv6-ula-global
            netmaskLength: 40
            allocations:
              netmaskLength:
                default: 44

          # Regional ULA pool
          - name: ipv6-ula-us-east-1
            sourcePoolRef: ipv6-ula-global
            locale: us-east-1
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 48

        gua:
          # Amazon-provided public IPv6
          - name: ipv6-gua-us-east-1
            locale: us-east-1
            netmaskLength: 52
            publicIpSource: amazon
            awsService: ec2
            allocations:
              netmaskLength:
                default: 56
```

### Stage 4: Enterprise

You have dedicated teams, compliance requirements, and need centralized services.

**What changes:**
- Dedicated accounts for security tooling, shared services, logging
- Delegated administration (Identity Center and IPAM managed from shared-services, not management account)
- Separate IPAM pools per environment with RAM sharing to OUs
- More granular permission sets

**Why delegate administration?**
- Management account should only manage Organizations
- Reduces blast radius if credentials are compromised
- Teams can self-service within their delegated scope

**Why separate IPAM pools?**
- Prod and dev don't compete for IP space
- Different allocation sizes per environment
- Clear boundaries and quotas

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: acme
  namespace: default
spec:
  managementPolicies: ["*"]

  aws:
    providerConfig: management-account
    region: us-east-1

  tags:
    organization: acme

  organization:
    awsServiceAccessPrincipals:
      - sso.amazonaws.com
      - ipam.amazonaws.com
      - ram.amazonaws.com

  organizationalUnits:
    - path: Security
    - path: Infrastructure
    - path: Workloads
    - path: Workloads/Prod
    - path: Workloads/NonProd

  accounts:
    # Security account - GuardDuty, Security Hub, CloudTrail
    - name: acme-security
      email: aws-security@acme.example.com
      ou: Security

    # Shared services - Identity Center admin, IPAM admin, CI/CD
    - name: acme-shared
      email: aws-shared@acme.example.com
      ou: Infrastructure

    # Workload accounts
    - name: acme-prod
      email: aws-prod@acme.example.com
      ou: Workloads/Prod

    - name: acme-staging
      email: aws-staging@acme.example.com
      ou: Workloads/NonProd

    - name: acme-dev
      email: aws-dev@acme.example.com
      ou: Workloads/NonProd

  # Delegate Identity Center and IPAM to shared-services
  delegatedAdministrators:
    - servicePrincipal: sso.amazonaws.com
      account: acme-shared
    - servicePrincipal: ipam.amazonaws.com
      account: acme-shared

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: PlatformAdmins
        description: Full access to all accounts
      - name: SecurityTeam
        description: Security tooling access
      - name: ProdEngineers
        description: Production deployment access
      - name: Developers
        description: Development environment access

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [PlatformAdmins]
        assignToAccounts: [acme-shared, acme-security, acme-prod, acme-staging, acme-dev]

      - name: SecurityAudit
        managedPolicies:
          - arn:aws:iam::aws:policy/SecurityAudit
        assignToGroups: [SecurityTeam]
        assignToAccounts: [acme-security, acme-prod, acme-staging, acme-dev]

      - name: ProdDeploy
        sessionDuration: PT2H  # Short sessions for prod
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [ProdEngineers]
        assignToAccounts: [acme-prod]

      - name: DevAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [Developers]
        assignToAccounts: [acme-staging, acme-dev]

  ipam:
    delegatedAdminAccount: acme-shared
    region: us-east-1
    operatingRegions: [us-east-1, us-west-2]

    pools:
      # ═══════════════════════════════════════════════════════════
      # IPv4 Hierarchy: Global → Regional → Environment
      # ═══════════════════════════════════════════════════════════
      ipv4:
        # Global pool - top of hierarchy
        - name: ipv4-global
          cidr: 10.0.0.0/8
          allocations:
            netmaskLength:
              default: 10  # Carve /10 per region

        # --- us-east-1 regional pools ---
        - name: ipv4-us-east-1
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.0.0.0/10      # 10.0.0.0 - 10.63.255.255
          allocations:
            netmaskLength:
              default: 12

        # Production pool - shared with Workloads/Prod OU
        - name: ipv4-us-east-1-prod
          sourcePoolRef: ipv4-us-east-1
          locale: us-east-1
          cidr: 10.0.0.0/12      # 10.0.0.0 - 10.15.255.255
          allocations:
            netmaskLength:
              default: 16
          ramShareTargets:
            - ou: Workloads/Prod

        # Non-prod pool - shared with Workloads/NonProd OU
        - name: ipv4-us-east-1-nonprod
          sourcePoolRef: ipv4-us-east-1
          locale: us-east-1
          cidr: 10.16.0.0/12     # 10.16.0.0 - 10.31.255.255
          allocations:
            netmaskLength:
              default: 16
          ramShareTargets:
            - ou: Workloads/NonProd

        # Shared services pool
        - name: ipv4-us-east-1-shared
          sourcePoolRef: ipv4-us-east-1
          locale: us-east-1
          cidr: 10.32.0.0/16     # 10.32.0.0 - 10.32.255.255
          allocations:
            netmaskLength:
              default: 20
          ramShareTargets:
            - account: acme-shared

        # --- us-west-2 regional pools (DR/multi-region) ---
        - name: ipv4-us-west-2
          sourcePoolRef: ipv4-global
          locale: us-west-2
          cidr: 10.64.0.0/10     # 10.64.0.0 - 10.127.255.255
          allocations:
            netmaskLength:
              default: 12

        - name: ipv4-us-west-2-prod
          sourcePoolRef: ipv4-us-west-2
          locale: us-west-2
          cidr: 10.64.0.0/12
          allocations:
            netmaskLength:
              default: 16
          ramShareTargets:
            - ou: Workloads/Prod

      # ═══════════════════════════════════════════════════════════
      # IPv6 Pools
      # ═══════════════════════════════════════════════════════════
      ipv6:
        # ULA (private) pools - fd00::/8, not internet-routable
        ula:
          # Global ULA pool
          - name: ipv6-ula-global
            netmaskLength: 40
            allocations:
              netmaskLength:
                default: 44

          # Regional ULA - us-east-1
          - name: ipv6-ula-us-east-1
            sourcePoolRef: ipv6-ula-global
            locale: us-east-1
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 48
            ramShareTargets:
              - ou: Workloads

          # Regional ULA - us-west-2
          - name: ipv6-ula-us-west-2
            sourcePoolRef: ipv6-ula-global
            locale: us-west-2
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 48
            ramShareTargets:
              - ou: Workloads

        # GUA (public) pools - Amazon-provided, internet-routable
        gua:
          - name: ipv6-gua-us-east-1
            locale: us-east-1
            netmaskLength: 52
            publicIpSource: amazon
            awsService: ec2
            allocations:
              netmaskLength:
                default: 56
            ramShareTargets:
              - ou: Workloads

          - name: ipv6-gua-us-west-2
            locale: us-west-2
            netmaskLength: 52
            publicIpSource: amazon
            awsService: ec2
            allocations:
              netmaskLength:
                default: 56
            ramShareTargets:
              - ou: Workloads
```

### Stage 5: Import Existing Resources

Already have an AWS Organization, Identity Center, or IPAM? Import them to bring existing infrastructure under GitOps management.

**Why import?**
- Preserve existing configurations - no disruption to running workloads
- Gradual adoption - import what you have, extend with new resources
- AWS allows only one Organization per account - you must import it

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: Foundation
metadata:
  name: acme
  namespace: default
spec:
  # Observe and update, but don't delete if this resource is removed
  managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]

  aws:
    providerConfig: management-account
    region: us-east-1

  # Import existing Organization
  # Get ID from: aws organizations describe-organization
  organization:
    externalName: o-abc123xyz
    awsServiceAccessPrincipals:
      - sso.amazonaws.com

  # Import existing OUs and accounts
  organizationalUnits:
    - path: Security
      externalName: ou-abc1-security  # Import existing OU
      accounts:
        - name: acme-security
          email: aws-security@acme.example.com
          externalName: "111111111111"  # Import existing account
          managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]

    - path: Workloads/Prod
      externalName: ou-abc1-prod
      accounts:
        - name: acme-prod
          email: aws-prod@acme.example.com
          externalName: "222222222222"
          managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    # Import existing groups
    groups:
      - name: Administrators
        externalName: d1fb9590-0091-7072-55a4-dd0778f5d5cb
        managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]

    # Import existing permission sets
    permissionSets:
      - name: AdministratorAccess
        # Format: PERMISSION_SET_ARN,INSTANCE_ARN
        externalName: arn:aws:sso:::permissionSet/ssoins-abcdef/ps-12345,arn:aws:sso:::instance/ssoins-abcdef
        managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess

  # Import existing IPAM
  ipam:
    externalName: ipam-0123456789abcdef0
    homeRegion: us-east-1
    operatingRegions: [us-east-1]

    pools:
      - name: ipv4
        addressFamily: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        externalName: ipam-pool-0123456789abcdef0
        # Format: cidr_pool-id
        cidrExternalName: 10.0.0.0/8_ipam-pool-0123456789abcdef0
        managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
```

## Using Account ProviderConfigs

Foundation creates a ProviderConfig for each account that assumes `OrganizationAccountAccessRole`. Reference accounts by name in downstream resources:

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: VPC
spec:
  providerConfigRef:
    name: acme-prod  # Assumes role into acme-prod account
  forProvider:
    region: us-east-1
    ipv4IpamPoolId: <from-foundation-status>
    ipv4NetmaskLength: 20
```

## Using IPAM Pools

Reference pool IDs from status when creating VPCs:

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: VPC
spec:
  forProvider:
    region: us-east-1
    # IPv4 from IPAM pool
    ipv4IpamPoolId: ipam-pool-abc123  # From status.ipam.pools[name=ipv4].id
    ipv4NetmaskLength: 20
    # IPv6 for dual-stack (optional)
    ipv6IpamPoolId: ipam-pool-xyz789  # From status.ipam.pools[name=ipv6-public].id
    ipv6NetmaskLength: 56
```

## Status

Foundation surfaces status from all components:

```yaml
status:
  ready: true
  organization:
    organizationId: o-abc123
    rootId: r-abc1
  organizationalUnits:
    Workloads/Prod: ou-xxx-prod
    Workloads/NonProd: ou-xxx-nonprod
  accounts:
    - name: acme-prod
      id: "111111111111"
      ready: true
    - name: acme-dev
      id: "222222222222"
      ready: true
  identityCenter:
    ready: true
  ipam:
    ready: true
    id: ipam-12345678
    pools:
      - name: prod-ipv4
        id: ipam-pool-abc123
```

## Recommendations

### Identity Center

- **Use groups, not direct user assignments** - Easier to manage at scale
- **Short sessions for admin access** - PT2H or less for AdministratorAccess
- **Longer sessions for daily work** - PT8H for developers improves productivity
- **Add guardrails via inline policy** - Deny dangerous actions in PowerUserAccess
- **Federate when ready** - Start with local users, migrate to IdP later

### Organization

- **Management account should only manage the Organization** - Delegate everything else
- **Delegate administration** - Move Identity Center and IPAM to shared-services account
- **Use path-based OUs** - Security, Infrastructure, Workloads/Prod, Workloads/NonProd

### IPAM

- **Start with IPAM early** - Prevents painful migrations later
- **Right-size VPCs** - /20 (4096 IPs) is enough for most workloads, not /16
- **Use allocation rules** - min/max netmask prevents wasteful oversizing
- **Plan for dual-stack** - IPv6 eliminates IP exhaustion concerns
- **Separate pools per environment** - Prod and non-prod don't compete for IP space

### IPv6 Pool Sizing Reference

| Level | Netmask | Addresses | Typical Use |
|-------|---------|-----------|-------------|
| IPAM Pool (GUA) | /52 | 16 /56 VPCs | Regional allocation |
| VPC | /56 | 256 /64 subnets | Per-VPC allocation |
| Subnet | /64 | 18 quintillion | Standard subnet size |
| EKS Node Prefix | /80 | ~65k pod IPs | Prefix delegation per node |

## AWS Service Principals

Enable these in `organization.awsServiceAccessPrincipals` based on your needs:

| Service | Principal | Purpose |
|---------|-----------|---------|
| Identity Center | `sso.amazonaws.com` | SSO and account assignments |
| IPAM | `ipam.amazonaws.com` | Cross-account IP management |
| RAM | `ram.amazonaws.com` | Resource sharing (IPAM pools) |
| CloudTrail | `cloudtrail.amazonaws.com` | Centralized audit logs |
| GuardDuty | `guardduty.amazonaws.com` | Threat detection |
| Security Hub | `securityhub.amazonaws.com` | Security findings |
| Config | `config.amazonaws.com` | Resource compliance |

## References

**Foundation sub-modules:**
- [aws-organization](../aws-organization/README.md) - Organization, OUs, accounts, delegated administrators
- [aws-identity-center](../aws-identity-center/README.md) - SSO groups, users, permission sets, federation
- [aws-ipam](../aws-ipam/README.md) - IP pools, dual-stack IPv6, RAM sharing

**Network allocation (use after Foundation is ready):**
- [aws-ipv4-network-allocation](../aws-ipv4-network-allocation/README.md) - Allocate IPv4 CIDRs from regional pools
- [aws-ipv6-ula-network-allocation](../aws-ipv6-ula-network-allocation/README.md) - Allocate IPv6 ULA CIDRs from regional pools
- [aws-network](../aws-network/README.md) - Create VPCs and subnets using allocated CIDRs

**AWS documentation:**
- [IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/)
- [Amazon VPC IPAM Best Practices](https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-vpc-ip-address-manager-best-practices/)
- [IPv6 on AWS Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/ipv6-on-aws/ipv6-on-aws.html)
- [Dual-stack IPv6 Architectures](https://aws.amazon.com/blogs/networking-and-content-delivery/dual-stack-ipv6-architectures-for-aws-and-hybrid-networks/)

## Development

```bash
make render-individual     # Stage 1 example
make render-enterprise     # Stage 4 example
make render-minimal        # Organization only
make test                  # Run tests
make validate              # Validate compositions
make e2e                   # E2E tests
```

## License

Apache-2.0
