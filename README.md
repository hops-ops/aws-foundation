# configuration-aws-foundation

Foundation provides a single resource to manage your entire AWS foundation, from solo developer to enterprise. Start simple and evolve as you grow.

## What Foundation Composes

Foundation is a unified API that composes four specialized XRDs:

| Component | Purpose | Documentation |
|-----------|---------|---------------|
| **[Organization](../aws-organization)** | AWS Organization, OUs, accounts, delegated administrators | Consolidated billing, SCPs, account factory |
| **[Identity Center](../aws-identity-center)** | SSO groups, users, permission sets, account assignments | Single sign-on, time-limited credentials, federation-ready |
| **[IPAM](../aws-ipam)** | IP address pools, automatic allocation, RAM sharing | No overlapping CIDRs, dual-stack IPv6, compliance tracking |
| **[Network](../aws-network)** | VPCs, subnets, route tables, NAT gateways | Per-account VPCs with IPAM allocation, consistent layouts |

**Why one resource?**
- Account names are referenced everywhere and automatically resolved to AWS account IDs
- OU paths are resolved for IPAM RAM sharing
- Each account gets a ProviderConfig for cross-account access via `OrganizationAccountAccessRole`
- IPAM pool names are resolved to pool IDs for network CIDR allocation
- Networks automatically target the correct account via their ProviderConfig
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

  # ═══════════════════════════════════════════════════════════════════
  # Network - dual-stack VPC with IPAM allocation
  # ═══════════════════════════════════════════════════════════════════
  networks:
    - name: main
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1      # Reference pool by name
          netmaskLength: 16            # /16 = 65k IPs, room to grow
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1  # Private IPv6
          netmaskLength: 56
      subnetLayout:
        availabilityZones: [a]         # Single AZ keeps it simple and cheap
        public:
          enabled: true
          netmaskLength: 24
        private:
          enabled: true
          netmaskLength: 20
      nat:
        enabled: false                 # No NAT - use IPv6 or bastion for egress
```

**Why this network config?**
- **Dual-stack** - IPv4 for compatibility, IPv6 for the future
- **Single AZ** - Simple and cheap; add AZs when you need HA
- **No NAT** - NAT gateways cost ~$32/month; use IPv6 egress or a bastion instead
- **poolRef** - Reference pools by name; Foundation resolves to pool IDs automatically

### Stage 2: Small Team

You're hiring. You need different access levels and maybe a separate dev environment.

**What changes:**
- Add groups for different roles (Developers, ReadOnly)
- Add more permission sets with appropriate policies
- Upgrade network to 3 AZs for high availability and HA stateful workloads (PostgreSQL, etc.)
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

```yaml
# Upgrade network to 3 AZs for stateful workloads:
networks:
  - name: main
    region: us-east-1
    ipam:
      ipv4:
        poolRef: ipv4-us-east-1
        netmaskLength: 16            # /16 = 65k IPs, room to grow
      ipv6Ula:
        poolRef: ipv6-ula-us-east-1
        netmaskLength: 56
    subnetLayout:
      availabilityZones: [a, b, c]   # 3 AZs for stateful apps (PostgreSQL, etc.)
      public:
        enabled: true
        netmaskLength: 24
      private:
        enabled: true
        netmaskLength: 20
    nat:
      enabled: true
      strategy: SingleAz             # NAT in one AZ, saves $64/month vs HA
```

### Stage 3: Multiple Teams

You're growing. A second team needs their own account and VPC.

**What you need:**
- AWS Organization to create and manage accounts
- Organizational Units (OUs) for grouping team accounts
- Permission sets assigned per team
- IPAM pools shared across team accounts

**Why Organizations?**
- Consolidated billing
- Service Control Policies (SCPs) for guardrails
- Centralized Identity Center management
- Account factory - spin up new team accounts in minutes

**Why account-per-team?**
- Blast radius isolation between teams
- Clear cost attribution
- Teams own their infrastructure

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

  # Enable AWS Organizations
  organization:
    awsServiceAccessPrincipals:
      - iam.amazonaws.com
      - sso.amazonaws.com
      - account.amazonaws.com

  # Create OU hierarchy
  organizationalUnits:
    - path: Teams
    - path: Teams/Alpha
    - path: Teams/Beta

  # Team accounts
  accounts:
    - name: acme-alpha
      email: aws-alpha@acme.example.com
      ou: Teams/Alpha

    - name: acme-beta
      email: aws-beta@acme.example.com
      ou: Teams/Beta

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: Administrators
      - name: TeamAlpha
      - name: TeamBeta

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [Administrators]
        assignToAccounts: [acme-alpha, acme-beta]

      # Each team gets access to their account only
      - name: TeamAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [TeamAlpha]
        assignToAccounts: [acme-alpha]

      - name: TeamAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [TeamBeta]
        assignToAccounts: [acme-beta]

  ipam:
    region: us-east-1
    operatingRegions: [us-east-1]

    pools:
      ipv4:
        - name: ipv4-global
          cidr: 10.0.0.0/8
          allocations:
            netmaskLength:
              default: 12

        # Regional pool shared with all teams
        - name: ipv4-us-east-1
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.0.0.0/12
          allocations:
            netmaskLength:
              default: 16
          ramShareTargets:
            - ou: Teams

      ipv6:
        ula:
          - name: ipv6-ula-global
            netmaskLength: 40
            allocations:
              netmaskLength:
                default: 44

          - name: ipv6-ula-us-east-1
            sourcePoolRef: ipv6-ula-global
            locale: us-east-1
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 56
            ramShareTargets:
              - ou: Teams

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
              - ou: Teams

  # ═══════════════════════════════════════════════════════════════════
  # Networks - each team gets their own VPC
  # ═══════════════════════════════════════════════════════════════════
  networks:
    # Team Alpha VPC
    - name: alpha
      account: acme-alpha
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56
      subnetLayout:
        availabilityZones: [a, b, c]
        public:
          enabled: true
          netmaskLength: 24
        private:
          enabled: true
          netmaskLength: 20
      nat:
        enabled: true
        strategy: SingleAz

    # Team Beta VPC
    - name: beta
      account: acme-beta
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56
      subnetLayout:
        availabilityZones: [a, b, c]
        public:
          enabled: true
          netmaskLength: 24
        private:
          enabled: true
          netmaskLength: 20
      nat:
        enabled: true
        strategy: SingleAz
```

### Stage 4: Enterprise

You have multiple product teams, compliance requirements, and need centralized services.

**What changes:**
- Account-per-team model with dedicated VPCs
- Dedicated accounts for security tooling, shared services, logging
- Delegated administration (Identity Center and IPAM managed from platform, not management account)
- Separate IPAM pools per team with RAM sharing
- Team-specific permission sets

**Why account-per-team?**
- Blast radius isolation - one team's misconfiguration doesn't affect others
- Clear cost attribution per team
- Teams own their infrastructure, platform provides guardrails
- Easier compliance and audit boundaries

**Why delegate administration?**
- Management account should only manage Organizations
- Reduces blast radius if credentials are compromised
- Teams can self-service within their delegated scope

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
      - iam.amazonaws.com
      - sso.amazonaws.com
      - account.amazonaws.com
      - ipam.amazonaws.com
      - ram.amazonaws.com

  organizationalUnits:
    - path: Security
    - path: Platform
    - path: Teams
    - path: Teams/Alpha
    - path: Teams/Beta
    - path: Teams/Data

  accounts:
    # Security account - GuardDuty, Security Hub, CloudTrail
    - name: acme-security
      email: aws-security@acme.example.com
      ou: Security

    # Platform - Identity Center admin, IPAM admin, CI/CD, shared tooling
    - name: acme-platform
      email: aws-platform@acme.example.com
      ou: Platform

    # Team accounts - each team owns their account
    - name: acme-alpha
      email: aws-alpha@acme.example.com
      ou: Teams/Alpha

    - name: acme-beta
      email: aws-beta@acme.example.com
      ou: Teams/Beta

    - name: acme-data
      email: aws-data@acme.example.com
      ou: Teams/Data

  # Delegate Identity Center and IPAM to platform
  delegatedAdministrators:
    - servicePrincipal: sso.amazonaws.com
      account: acme-platform
    - servicePrincipal: ipam.amazonaws.com
      account: acme-platform

  identityCenter:
    region: us-east-1
    identityStoreId: d-1234567890
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef

    groups:
      - name: PlatformAdmins
        description: Full access to all accounts
      - name: SecurityTeam
        description: Security tooling access
      - name: TeamAlpha
        description: Alpha team members
      - name: TeamBeta
        description: Beta team members
      - name: DataEngineers
        description: Data team members

    permissionSets:
      - name: AdministratorAccess
        managedPolicies:
          - arn:aws:iam::aws:policy/AdministratorAccess
        assignToGroups: [PlatformAdmins]
        assignToAccounts: [acme-platform, acme-security, acme-alpha, acme-beta, acme-data]

      - name: SecurityAudit
        managedPolicies:
          - arn:aws:iam::aws:policy/SecurityAudit
        assignToGroups: [SecurityTeam]
        assignToAccounts: [acme-security, acme-alpha, acme-beta, acme-data]

      # Team-specific access - each team only gets access to their account
      - name: TeamAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [TeamAlpha]
        assignToAccounts: [acme-alpha]

      - name: TeamAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [TeamBeta]
        assignToAccounts: [acme-beta]

      - name: DataAccess
        sessionDuration: PT8H
        managedPolicies:
          - arn:aws:iam::aws:policy/PowerUserAccess
        assignToGroups: [DataEngineers]
        assignToAccounts: [acme-data]

  ipam:
    delegatedAdminAccount: acme-platform
    region: us-east-1
    operatingRegions: [us-east-1]

    pools:
      # ═══════════════════════════════════════════════════════════
      # IPv4 Hierarchy: Global → Regional → shared with Teams OU
      # ═══════════════════════════════════════════════════════════
      ipv4:
        # Global pool - top of hierarchy
        - name: ipv4-global
          cidr: 10.0.0.0/8
          allocations:
            netmaskLength:
              default: 12  # Carve /12 per region

        # Regional pool - shared with all teams
        - name: ipv4-us-east-1
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.0.0.0/12
          allocations:
            netmaskLength:
              default: 16
          ramShareTargets:
            - ou: Teams              # All team accounts can allocate

        # Platform pool
        - name: ipv4-us-east-1-platform
          sourcePoolRef: ipv4-global
          locale: us-east-1
          cidr: 10.16.0.0/16
          allocations:
            netmaskLength:
              default: 20
          ramShareTargets:
            - account: acme-platform

      # ═══════════════════════════════════════════════════════════
      # IPv6 Pools - shared with Teams OU
      # ═══════════════════════════════════════════════════════════
      ipv6:
        ula:
          - name: ipv6-ula-global
            netmaskLength: 40
            allocations:
              netmaskLength:
                default: 44

          - name: ipv6-ula-us-east-1
            sourcePoolRef: ipv6-ula-global
            locale: us-east-1
            netmaskLength: 44
            allocations:
              netmaskLength:
                default: 56
            ramShareTargets:
              - ou: Teams

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
              - ou: Teams

  # ═══════════════════════════════════════════════════════════════════
  # Network Defaults - consistent subnet layouts
  # ═══════════════════════════════════════════════════════════════════
  networkDefaults:
    subnetLayout:
      availabilityZones: [a, b, c]
      public:
        enabled: true
        netmaskLength: 24
      private:
        enabled: true
        netmaskLength: 20
    nat:
      enabled: true
      strategy: SingleAz

  # ═══════════════════════════════════════════════════════════════════
  # Networks - each team gets their own VPC
  # ═══════════════════════════════════════════════════════════════════
  networks:
    # Team Alpha VPC
    - name: alpha
      account: acme-alpha
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56

    # Team Beta VPC
    - name: beta
      account: acme-beta
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56

    # Data team VPC
    - name: data
      account: acme-data
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56

    # Platform VPC - shared tooling, CI/CD
    - name: platform
      account: acme-platform
      region: us-east-1
      ipam:
        ipv4:
          poolRef: ipv4-us-east-1-platform
          netmaskLength: 16
        ipv6Ula:
          poolRef: ipv6-ula-us-east-1
          netmaskLength: 56
```

**Network status:**
```yaml
status:
  networks:
    - name: alpha
      account: acme-alpha
      region: us-east-1
      ready: true
      vpcId: vpc-abc123
      cidr:
        ipv4: "10.0.0.0/16"
```

### Stage 5: Import Existing Resources

Already have an AWS Organization, Identity Center, IPAM, or VPCs? Import them to bring existing infrastructure under GitOps management.

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
      - iam.amazonaws.com
      - sso.amazonaws.com
      - account.amazonaws.com

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

  # Import existing VPCs
  # Get IDs: aws ec2 describe-vpcs, describe-subnets, describe-route-tables
  networks:
    - name: production
      account: acme-prod
      region: us-east-1
      managementPolicies: ["Observe"]  # Observe-only at network level

      # Direct pool ID (use when pool is external to Foundation)
      ipam:
        ipv4:
          poolId: ipam-pool-abc123     # Direct ID, not poolRef
          netmaskLength: 16

      # Import VPC by ID
      vpc:
        externalName: vpc-0123456789abcdef0
        managementPolicies: ["Observe"]

      # Import Internet Gateway
      internetGateway:
        externalName: igw-0123456789abcdef0
        managementPolicies: ["Observe"]

      # Import subnets by name → ID mapping
      subnetLayout:
        availabilityZones: [a, b, c]
        public:
          enabled: true
          netmaskLength: 24
        private:
          enabled: true
          netmaskLength: 20
        externalNames:
          public-a: subnet-pub-a-123
          public-b: subnet-pub-b-456
          public-c: subnet-pub-c-789
          private-a: subnet-priv-a-123
          private-b: subnet-priv-b-456
          private-c: subnet-priv-c-789
        managementPolicies: ["Observe"]

      # Import route tables
      routeTables:
        externalNames:
          public: rtb-pub-123
          private-a: rtb-priv-a-123
          private-b: rtb-priv-b-456
          private-c: rtb-priv-c-789
        associationExternalNames:
          public-a: rtbassoc-pub-a-123
          public-b: rtbassoc-pub-b-456
          public-c: rtbassoc-pub-c-789
          private-a: rtbassoc-priv-a-123
          private-b: rtbassoc-priv-b-456
          private-c: rtbassoc-priv-c-789
        managementPolicies: ["Observe"]

      nat:
        enabled: false  # Import doesn't manage NAT
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
  networks:
    - name: production
      account: acme-prod
      region: us-east-1
      ready: true
      vpcId: vpc-abc123def
      cidr:
        ipv4: "10.0.0.0/16"
    - name: staging
      account: acme-staging
      region: us-east-1
      ready: true
      vpcId: vpc-def456ghi
      cidr:
        ipv4: "10.16.0.0/16"
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

### Networks

- **Use networkDefaults** - Define consistent subnet layouts once, override where needed
- **Use poolRef, not poolId** - Reference pools by name for clarity and maintainability
- **Right-size per environment** - Production needs HA NAT and 3 AZs; dev can use 1 AZ with no NAT
- **Omit account for management account** - Networks without `account` target `spec.providerConfigRef`
- **Import existing VPCs** - Use `externalName` and `managementPolicies: ["Observe"]` to adopt VPCs

### IPv6 Pool Sizing Reference

| Level | Netmask | Addresses | Typical Use |
|-------|---------|-----------|-------------|
| IPAM Pool (GUA) | /52 | 16 /56 VPCs | Regional allocation |
| VPC | /56 | 256 /64 subnets | Per-VPC allocation |
| Subnet | /64 | 18 quintillion | Standard subnet size |
| EKS Node Prefix | /80 | ~65k pod IPs | Prefix delegation per node |

## AWS Service Principals

Enable these in `organization.awsServiceAccessPrincipals`. The first three are required for most Organizations:

| Service | Principal | Purpose |
|---------|-----------|---------|
| **IAM** | `iam.amazonaws.com` | Cross-account IAM roles (required) |
| **Identity Center** | `sso.amazonaws.com` | SSO and account assignments (required) |
| **Account Management** | `account.amazonaws.com` | Account lifecycle management (required) |
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
- [aws-network](../aws-network/README.md) - VPCs, subnets, route tables, NAT gateways

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
make render-with-networks  # Stage 4 example with networks
make render-minimal        # Organization only
make test                  # Run tests
make validate              # Validate compositions
make e2e                   # E2E tests
```

## License

Apache-2.0
