import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

_items = [
    # =========================================================================
    # Individual Example Tests
    # =========================================================================
    # Tests for single-account foundation without Organization
    # Foundation creates IdentityCenter and IPAM XRDs (not underlying managed resources)

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-individual-identity-center"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/individual.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # IdentityCenter XRD - asserts the Foundation creates the IdentityCenter XRD
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IdentityCenter"
                    metadata: {
                        name: "my-foundation-identity-center"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                            kind: "ProviderConfig"
                        }
                        region: "us-east-1"
                        identityStoreId: "d-1234567890"
                        organizationName: "my-foundation"
                        identityCenter: {
                            instanceArn: "arn:aws:sso:::instance/ssoins-abcdef0123456789"
                            sessionDuration: "PT1H"
                        }
                        groups: [
                            {
                                name: "Administrators"
                                description: "Full administrative access"
                            },
                            {
                                name: "Developers"
                                description: "Development access for building and deploying"
                            },
                            {
                                name: "ReadOnly"
                                description: "Read-only access for viewing resources"
                            }
                        ]
                        permissionSets: [
                            {
                                name: "AdministratorAccess"
                                description: "Full administrator access"
                                sessionDuration: "PT4H"
                                managedPolicies: ["arn:aws:iam::aws:policy/AdministratorAccess"]
                            },
                            {
                                name: "PowerUserAccess"
                                description: "Developer access without IAM management"
                                sessionDuration: "PT8H"
                                managedPolicies: ["arn:aws:iam::aws:policy/PowerUserAccess"]
                            },
                            {
                                name: "ViewOnlyAccess"
                                description: "Read-only access for review"
                                sessionDuration: "PT1H"
                                managedPolicies: ["arn:aws:iam::aws:policy/ViewOnlyAccess"]
                            }
                        ]
                    }
                }
            ]
        }
    },

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-individual-ipam"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/individual.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # IPAM XRD - pools passed through directly with nested structure
                # Now includes hierarchical pools with sourcePoolRef
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPAM"
                    metadata: {
                        name: "my-foundation-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                            kind: "ProviderConfig"
                        }
                        region: "us-east-1"
                        operatingRegions: ["us-east-1"]
                        pools: {
                            ipv4: [
                                {
                                    name: "ipv4-global"
                                    cidr: "10.0.0.0/8"
                                    allocations: {
                                        netmaskLength: {
                                            default: 12
                                        }
                                    }
                                    description: "Global IPv4 pool"
                                },
                                {
                                    name: "ipv4-us-east-1"
                                    sourcePoolRef: "ipv4-global"
                                    locale: "us-east-1"
                                    cidr: "10.0.0.0/12"
                                    allocations: {
                                        netmaskLength: {
                                            default: 16
                                            min: 16
                                            max: 24
                                        }
                                    }
                                    description: "Regional IPv4 pool for us-east-1 VPCs"
                                }
                            ]
                            ipv6: {
                                ula: [
                                    {
                                        name: "ipv6-ula-global"
                                        netmaskLength: 40
                                        allocations: {
                                            netmaskLength: {
                                                default: 44
                                            }
                                        }
                                        description: "Global ULA IPv6 pool"
                                    },
                                    {
                                        name: "ipv6-ula-us-east-1"
                                        sourcePoolRef: "ipv6-ula-global"
                                        locale: "us-east-1"
                                        netmaskLength: 44
                                        allocations: {
                                            netmaskLength: {
                                                default: 48
                                                min: 48
                                                max: 56
                                            }
                                        }
                                        description: "Regional ULA IPv6 for us-east-1 VPCs"
                                    }
                                ]
                                gua: [
                                    {
                                        name: "ipv6-gua-us-east-1"
                                        locale: "us-east-1"
                                        netmaskLength: 52
                                        publicIpSource: "amazon"
                                        awsService: "ec2"
                                        allocations: {
                                            netmaskLength: {
                                                default: 56
                                                min: 52
                                                max: 60
                                            }
                                        }
                                        description: "Public IPv6 pool (Amazon GUA) for internet-facing workloads"
                                    }
                                ]
                            }
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example Tests - Initial Render
    # =========================================================================
    # Tests for multi-account foundation with Organization (team-based model)

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-organization"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # Organization XRD - asserts the Foundation creates the Organization XRD
                # Note: Foundation nests accounts inside OUs for the Organization XRD
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "Organization"
                    metadata: {
                        name: "acme"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "aws-management-account"
                            kind: "ProviderConfig"
                        }
                        tags: {
                            hops: "true"
                            organization: "acme"
                            "managed-by": "crossplane"
                        }
                        organization: {
                            managementPolicies: ["*"]
                            awsServiceAccessPrincipals: [
                                "iam.amazonaws.com",
                                "sso.amazonaws.com",
                                "account.amazonaws.com",
                                "ipam.amazonaws.com",
                                "ram.amazonaws.com"
                            ]
                        }
                        # Accounts are nested inside their respective OUs
                        organizationalUnits: [
                            {
                                path: "Security"
                                accounts: [
                                    {
                                        name: "acme-security"
                                        email: "aws-security@acme.example.com"
                                        tags: {team: "security"}
                                    }
                                ]
                            },
                            {
                                path: "Platform"
                                accounts: [
                                    {
                                        name: "acme-platform"
                                        email: "aws-platform@acme.example.com"
                                        tags: {team: "platform"}
                                    }
                                ]
                            },
                            {path: "Teams"},
                            {
                                path: "Teams/Alpha"
                                accounts: [
                                    {
                                        name: "acme-alpha"
                                        email: "aws-alpha@acme.example.com"
                                        tags: {team: "alpha"}
                                    }
                                ]
                            },
                            {
                                path: "Teams/Beta"
                                accounts: [
                                    {
                                        name: "acme-beta"
                                        email: "aws-beta@acme.example.com"
                                        tags: {team: "beta"}
                                    }
                                ]
                            },
                            {
                                path: "Teams/Data"
                                accounts: [
                                    {
                                        name: "acme-data"
                                        email: "aws-data@acme.example.com"
                                        tags: {team: "data"}
                                    }
                                ]
                            }
                        ]
                        delegatedAdministrators: [
                            {
                                servicePrincipal: "sso.amazonaws.com"
                                accountRef: {name: "acme-platform"}
                            },
                            {
                                servicePrincipal: "ipam.amazonaws.com"
                                accountRef: {name: "acme-platform"}
                            }
                        ]
                    }
                }
            ]
        }
    },

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-identity-center"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # IdentityCenter XRD - asserts the Foundation creates the IdentityCenter XRD
                # Note: On initial render without Organization ready, assignToAccounts is not populated
                # (account names resolve to IDs only after Organization status is available)
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IdentityCenter"
                    metadata: {
                        name: "acme-identity-center"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "aws-management-account"
                            kind: "ProviderConfig"
                        }
                        region: "us-east-1"
                        identityStoreId: "d-1234567890"
                        organizationName: "acme"
                        groups: [
                            {
                                name: "PlatformAdmins"
                                description: "Full access to all accounts"
                            },
                            {
                                name: "SecurityTeam"
                                description: "Security tooling access"
                            },
                            {
                                name: "TeamAlpha"
                                description: "Alpha team members"
                            },
                            {
                                name: "TeamBeta"
                                description: "Beta team members"
                            },
                            {
                                name: "DataEngineers"
                                description: "Data team members"
                            }
                        ]
                        permissionSets: [
                            {
                                name: "AdministratorAccess"
                                description: "Full administrator access"
                                sessionDuration: "PT4H"
                                managedPolicies: ["arn:aws:iam::aws:policy/AdministratorAccess"]
                                assignToGroups: ["PlatformAdmins"]
                            },
                            {
                                name: "SecurityAudit"
                                description: "Security audit access"
                                sessionDuration: "PT4H"
                                managedPolicies: ["arn:aws:iam::aws:policy/SecurityAudit"]
                                assignToGroups: ["SecurityTeam"]
                            },
                            {
                                name: "AlphaAccess"
                                description: "Team Alpha access"
                                sessionDuration: "PT8H"
                                managedPolicies: ["arn:aws:iam::aws:policy/PowerUserAccess"]
                                assignToGroups: ["TeamAlpha"]
                            },
                            {
                                name: "BetaAccess"
                                description: "Team Beta access"
                                sessionDuration: "PT8H"
                                managedPolicies: ["arn:aws:iam::aws:policy/PowerUserAccess"]
                                assignToGroups: ["TeamBeta"]
                            },
                            {
                                name: "DataAccess"
                                description: "Data team access"
                                sessionDuration: "PT8H"
                                managedPolicies: ["arn:aws:iam::aws:policy/PowerUserAccess"]
                                assignToGroups: ["DataEngineers"]
                            }
                        ]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - IPAM basic structure
    # =========================================================================
    # Tests that IPAM XRD is created with correct basic configuration
    # Note: Pool structure is passed through from Foundation, so we just verify
    # the IPAM resource is created with correct base settings

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-ipam-pool-structure"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # IPAM XRD - verify basic settings (pools are pass-through)
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPAM"
                    metadata: {
                        name: "acme-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "aws-management-account"
                            kind: "ProviderConfig"
                        }
                        region: "us-east-1"
                        operatingRegions: ["us-east-1"]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Account assignments resolved
    # =========================================================================
    # Tests that IdentityCenter gets account IDs from Organization status

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-identity-center-with-accounts"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # Organization XRD is ready with accounts
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "Organization"
                    metadata: {
                        name: "acme"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "organization"
                            "crossplane.io/composition-resource-name": "organization"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        organization: {
                            id: "o-acme12345"
                            managementAccountId: "111111111111"
                            rootId: "r-acme"
                        }
                        accounts: [
                            {name: "acme-security", id: "222222222222", ready: True},
                            {name: "acme-platform", id: "333333333333", ready: True},
                            {name: "acme-alpha", id: "444444444444", ready: True},
                            {name: "acme-beta", id: "555555555555", ready: True},
                            {name: "acme-data", id: "666666666666", ready: True}
                        ]
                    }
                }
            ]
            assertResources: [
                # IdentityCenter XRD should now have resolved account IDs for assignments
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IdentityCenter"
                    metadata: {
                        name: "acme-identity-center"
                    }
                    spec: {
                        permissionSets: [
                            {
                                name: "AdministratorAccess"
                                # Account names resolved to IDs from Organization status
                                assignToAccounts: ["333333333333", "222222222222", "444444444444", "555555555555", "666666666666"]
                            },
                            {
                                name: "SecurityAudit"
                                assignToAccounts: ["222222222222", "444444444444", "555555555555", "666666666666"]
                            },
                            {
                                name: "AlphaAccess"
                                assignToAccounts: ["444444444444"]
                            },
                            {
                                name: "BetaAccess"
                                assignToAccounts: ["555555555555"]
                            },
                            {
                                name: "DataAccess"
                                assignToAccounts: ["666666666666"]
                            }
                        ]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Default Tags Test
    # =========================================================================
    # Verify hops=true tag is always applied to Organization XRD

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-default-tags"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "Organization"
                    metadata: {
                        name: "acme"
                    }
                    spec: {
                        tags: {
                            hops: "true"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Account ProviderConfigs - Management Policies Test
    # =========================================================================
    # Tests that memberAccountsProviderConfigs.managementPolicies is propagated
    # to the generated Kubernetes Object resources

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-account-providerconfigs-management-policies"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: False
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "Foundation"
                metadata: {
                    name: "test-mgmt-policies"
                    namespace: "default"
                }
                spec: {
                    managementPolicies: ["Observe"]
                    aws: {
                        providerConfig: "default"
                        region: "us-east-1"
                    }
                    memberAccountsProviderConfigs: {
                        managementPolicies: ["*"]
                    }
                    organizationalUnits: [
                        {path: "Test"}
                    ]
                    accounts: [
                        {name: "test-account", email: "test@example.com", ou: "Test"}
                    ]
                }
            }
            observedResources: [
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "Organization"
                    metadata: {
                        name: "test-mgmt-policies"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "organization"
                            "crossplane.io/composition-resource-name": "organization"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        organization: {
                            id: "o-test123"
                            managementAccountId: "111111111111"
                            rootId: "r-test"
                        }
                        accounts: [
                            {name: "test-account", id: "222222222222", ready: True}
                        ]
                    }
                }
            ]
            assertResources: [
                {
                    apiVersion: "kubernetes.m.crossplane.io/v1alpha1"
                    kind: "Object"
                    metadata: {
                        name: "test-mgmt-policies-pc-test-account"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            manifest: {
                                metadata: {
                                    name: "test-account"
                                }
                                spec: {
                                    assumeRoleChain: [
                                        {roleARN: "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"}
                                    ]
                                }
                            }
                        }
                    }
                }
            ]
        }
    }
]
items = _items
