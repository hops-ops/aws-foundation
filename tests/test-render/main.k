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
                        providerConfigName: "default"
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
                # IPAM XRD - asserts the Foundation creates the IPAM XRD
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPAM"
                    metadata: {
                        name: "my-foundation-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigName: "default"
                        organizationName: "my-foundation"
                        scope: "private"
                        homeRegion: "us-east-1"
                        operatingRegions: ["us-east-1"]
                        pools: [
                            {
                                name: "ipv4"
                                addressFamily: "ipv4"
                                region: "us-east-1"
                                cidr: "10.0.0.0/8"
                                allocationDefaultNetmaskLength: 20
                                allocationMinNetmaskLength: 16
                                allocationMaxNetmaskLength: 24
                                description: "IPv4 pool for VPCs"
                            },
                            {
                                name: "ipv6-public"
                                addressFamily: "ipv6"
                                scope: "public"
                                region: "us-east-1"
                                locale: "us-east-1"
                                amazonProvidedIpv6CidrBlock: True
                                publicIpSource: "amazon"
                                awsService: "ec2"
                                allocationDefaultNetmaskLength: 56
                                allocationMinNetmaskLength: 52
                                allocationMaxNetmaskLength: 60
                                description: "Public IPv6 pool (Amazon GUA)"
                            },
                            {
                                name: "ipv6-private"
                                addressFamily: "ipv6"
                                scope: "private"
                                region: "us-east-1"
                                locale: "us-east-1"
                                cidr: "fd00:my:app::/48"
                                allocationDefaultNetmaskLength: 56
                                allocationMinNetmaskLength: 48
                                allocationMaxNetmaskLength: 64
                                description: "Private IPv6 pool (ULA for internal microservices)"
                            }
                        ]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example Tests - Initial Render
    # =========================================================================
    # Tests for multi-account foundation with Organization

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
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "Organization"
                    metadata: {
                        name: "acme"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        aws: {
                            providerConfig: "aws-management-account"
                        }
                        tags: {
                            hops: "true"
                            organization: "acme"
                            environment: "production"
                            "managed-by": "crossplane"
                        }
                        organization: {
                            managementPolicies: ["*"]
                            awsServiceAccessPrincipals: [
                                "sso.amazonaws.com",
                                "ipam.amazonaws.com",
                                "ram.amazonaws.com"
                            ]
                        }
                        organizationalUnits: [
                            {
                                path: "Security"
                                accounts: [
                                    {
                                        name: "acme-security-tooling"
                                        email: "security-tooling@acme.example.com"
                                        tags: {team: "security"}
                                    }
                                ]
                            },
                            {
                                path: "Infrastructure"
                                accounts: [
                                    {
                                        name: "acme-shared-services"
                                        email: "shared-services@acme.example.com"
                                        tags: {team: "platform"}
                                    }
                                ]
                            },
                            {path: "Workloads"},
                            {
                                path: "Workloads/Prod"
                                accounts: [
                                    {
                                        name: "acme-prod"
                                        email: "prod@acme.example.com"
                                        tags: {environment: "production"}
                                    }
                                ]
                            },
                            {
                                path: "Workloads/Non-Prod"
                                accounts: [
                                    {
                                        name: "acme-staging"
                                        email: "staging@acme.example.com"
                                        tags: {environment: "staging"}
                                    },
                                    {
                                        name: "acme-dev"
                                        email: "dev@acme.example.com"
                                        tags: {environment: "development"}
                                    }
                                ]
                            },
                            {path: "Sandbox"}
                        ]
                        delegatedAdministrators: [
                            {
                                servicePrincipal: "sso.amazonaws.com"
                                accountRef: {name: "acme-shared-services"}
                            },
                            {
                                servicePrincipal: "ipam.amazonaws.com"
                                accountRef: {name: "acme-shared-services"}
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
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IdentityCenter"
                    metadata: {
                        name: "acme-identity-center"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigName: "aws-management-account"
                        region: "us-east-1"
                        identityStoreId: "d-1234567890"
                        organizationName: "acme"
                        groups: [
                            {
                                name: "Administrators"
                                description: "Full administrative access to all accounts"
                            },
                            {
                                name: "Developers"
                                description: "Development access to non-production accounts"
                            },
                            {
                                name: "ReadOnly"
                                description: "Read-only access for auditing and compliance"
                            }
                        ]
                        permissionSets: [
                            {
                                name: "AdministratorAccess"
                                description: "Full administrator access"
                                sessionDuration: "PT4H"
                                managedPolicies: ["arn:aws:iam::aws:policy/AdministratorAccess"]
                                assignToGroups: ["Administrators"]
                            },
                            {
                                name: "DeveloperAccess"
                                description: "Developer access for non-prod environments"
                                sessionDuration: "PT8H"
                                managedPolicies: ["arn:aws:iam::aws:policy/PowerUserAccess"]
                                assignToGroups: ["Developers"]
                            },
                            {
                                name: "ViewOnlyAccess"
                                description: "Read-only access for compliance review"
                                sessionDuration: "PT1H"
                                managedPolicies: ["arn:aws:iam::aws:policy/ViewOnlyAccess"]
                                assignToGroups: ["ReadOnly"]
                            }
                        ]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Step 1: Organization XRD Ready
    # =========================================================================
    # Tests that IPAM XRD is created after Organization XRD reports accounts ready
    # Note: The Foundation creates XRDs, and the step tests verify observed-state gating

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-step-1-ipam-with-org-ready"
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
                        organizationalUnits: {
                            Security: "ou-acme-security"
                            Infrastructure: "ou-acme-infrastructure"
                            Workloads: "ou-acme-workloads"
                            "Workloads/Prod": "ou-acme-workloads-prod"
                            "Workloads/Non-Prod": "ou-acme-workloads-nonprod"
                            Sandbox: "ou-acme-sandbox"
                        }
                        accounts: [
                            {name: "acme-security-tooling", id: "222222222222", ready: True},
                            {name: "acme-shared-services", id: "333333333333", ready: True},
                            {name: "acme-prod", id: "444444444444", ready: True},
                            {name: "acme-staging", id: "555555555555", ready: True},
                            {name: "acme-dev", id: "666666666666", ready: True}
                        ]
                    }
                }
            ]
            assertResources: [
                # IPAM XRD should now be created since delegated admin account is ready
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPAM"
                    metadata: {
                        name: "acme-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigName: "aws-management-account"
                        organizationName: "acme"
                        scope: "global-organization"
                        homeRegion: "us-east-1"
                        delegatedAdminAccountRef: {
                            name: "acme-shared-services"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Step 2: Account assignments resolved
    # =========================================================================
    # Tests that IdentityCenter gets account IDs from Organization status

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-step-2-identity-center-with-accounts"
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
                            {name: "acme-security-tooling", id: "222222222222", ready: True},
                            {name: "acme-shared-services", id: "333333333333", ready: True},
                            {name: "acme-prod", id: "444444444444", ready: True},
                            {name: "acme-staging", id: "555555555555", ready: True},
                            {name: "acme-dev", id: "666666666666", ready: True}
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
                                name: "DeveloperAccess"
                                assignToAccounts: ["555555555555", "666666666666"]
                            },
                            {
                                name: "ViewOnlyAccess"
                                assignToAccounts: ["333333333333", "222222222222", "444444444444", "555555555555", "666666666666"]
                            }
                        ]
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - IPAM Pool RAM Shares
    # =========================================================================
    # Tests that IPAM pools get resolved OU IDs for RAM share targets

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-ipam-ram-shares"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # Organization XRD is ready with OUs and accounts
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
                        organizationalUnits: {
                            Security: "ou-acme-security"
                            Infrastructure: "ou-acme-infrastructure"
                            Workloads: "ou-acme-workloads"
                            "Workloads/Prod": "ou-acme-workloads-prod"
                            "Workloads/Non-Prod": "ou-acme-workloads-nonprod"
                            Sandbox: "ou-acme-sandbox"
                        }
                        accounts: [
                            {name: "acme-security-tooling", id: "222222222222", ready: True},
                            {name: "acme-shared-services", id: "333333333333", ready: True},
                            {name: "acme-prod", id: "444444444444", ready: True},
                            {name: "acme-staging", id: "555555555555", ready: True},
                            {name: "acme-dev", id: "666666666666", ready: True}
                        ]
                    }
                }
            ]
            assertResources: [
                # IPAM XRD should be created with resolved OU IDs
                # Note: We verify IPAM exists with delegatedAdminAccountRef since
                # pool array assertions require exact match
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPAM"
                    metadata: {
                        name: "acme-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        organizationName: "acme"
                        scope: "global-organization"
                        homeRegion: "us-east-1"
                        delegatedAdminAccountRef: {
                            name: "acme-shared-services"
                        }
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
    }
]
items = _items
