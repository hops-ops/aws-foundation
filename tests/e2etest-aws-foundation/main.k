# e2etest-aws-foundation - Import existing Organization, Identity Center, IPAM, and Network
# ==========================================================================================
# Tests Foundation's ability to import existing AWS resources via pass-through.
# This test imports:
# - Existing AWS Organization (with OUs and accounts)
# - Existing Identity Center instance (with groups and permission sets)
# - Existing IPAM (with pools)
# - Existing Network (VPC, subnets, route tables, gateways)
#
# All persisted resources use managementPolicies without Delete to preserve them.
# Prerequisites:
# - Run aws-ipam e2e test first to create the IPAM resources
# - Run aws-network e2e test first to create the persistent network
#
# NOTE: Uses untyped dicts for manifest because Foundation XRD uses extensive
# x-kubernetes-preserve-unknown-fields which KCL model generation doesn't support.

import base64
import file
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Configuration
# =============================================================================

_foundation_name = "hops-e2e-foundation"
_region = "us-east-2"

# Observe-only - don't modify resources managed by other repos
_observeOnly = ["Observe"]

# =============================================================================
# Existing Organization (from aws-organization e2e test)
# =============================================================================
# AWS only allows one org per account, so we adopt the existing one
_existing_org_id = "o-3lholziq1o"

# Test OU - persistent, imported via externalName
_test_ou_path = "Test"
_test_ou_external_name = "ou-hdvp-fbcb7sbw"

# Test account - persistent, orphaned on delete
_test_account_name = "configuration-aws-organization"
_test_account_email = "configuration-aws-organization@ops.com.ai"
_test_account_external_name = "544051101726"

# =============================================================================
# Existing Identity Center (AWS only allows one per org/account)
# =============================================================================
# Get these values with: aws sso-admin list-instances
_identity_store_id = "d-9a675288a4"
_instance_arn = "arn:aws:sso:::instance/ssoins-668444b406cda8b2"

# Persistent Identity Center resources - imported via externalName
_persistent_group_name = "hops-e2e-test"
_persistent_group_id = "d1fb9590-0091-7072-55a4-dd0778f5d5cb"

_persistent_permission_set_name = "E2EPersistentAccess"
_persistent_permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-668444b406cda8b2/ps-aaebc62f1ea517cc"
_persistent_permission_set_external_name = _persistent_permission_set_arn + "," + _instance_arn

# Note: Permission set assignments will use _test_account_name (resolved by Foundation)

# =============================================================================
# Existing IPAM (from aws-ipam e2e test)
# =============================================================================
# Get with: aws ec2 describe-ipams --query 'Ipams[*].[IpamId,Tags]'
_ipam_external_name = "ipam-0573c7815d0a36e00"

# Global IPv4 pool (10.0.0.0/8)
_ipv4_global_pool_external_name = "ipam-pool-0a82c73b97dc0dabb"
_ipv4_global_cidr_external_name = "10.0.0.0/8" + "_" + _ipv4_global_pool_external_name

# Regional IPv4 pool (10.0.0.0/12) - child of global, used by networks
_ipv4_regional_pool_external_name = "ipam-pool-0607416fa3707147a"
_ipv4_regional_cidr_external_name = "10.0.0.0/12" + "_" + _ipv4_regional_pool_external_name

# Global IPv6 private pool (ULA /32)
_ipv6_private_pool_external_name = "ipam-pool-02261bfded584dbfb"
_ipv6_private_cidr_external_name = "fda0:daf7::/32" + "_" + _ipv6_private_pool_external_name

# Regional IPv6 private pool (/48) - child of global, used by networks
_ipv6_private_regional_pool_external_name = "ipam-pool-0ca730678e463dbfc"
_ipv6_private_regional_cidr_external_name = "fda0:daf7:1::/48" + "_" + _ipv6_private_regional_pool_external_name

# =============================================================================
# Existing Network (from aws-network e2e test - "hops-test" network)
# =============================================================================

# VPC and gateway IDs
_network_vpc_external_name = "vpc-0c20c458dcb738f21"
_network_igw_external_name = "igw-0a11d99e3cc584333"
_network_eigw_external_name = "eigw-02d33bcb5e87d8353"

# Subnet external names (AZs a, b, c)
_network_subnet_external_names = {
    "private-a": "subnet-0ba2f584c25e9435d"
    "private-b": "subnet-02e4d512f8859e684"
    "private-c": "subnet-0a46f41be19e3ef54"
    "public-a": "subnet-0f17f94da9c13d3fe"
    "public-b": "subnet-0f09414e8042cbee9"
    "public-c": "subnet-0739c3679702306eb"
}

# Route table external names
_network_rt_external_names = {
    "public": "rtb-0ec6e6b72b4069f6d"
    "private-a": "rtb-0123083a1a6980352"
    "private-b": "rtb-0f3651ed2fa86b78c"
    "private-c": "rtb-00bcd173ff8e26c91"
}

# Route table association external names
_network_rta_external_names = {
    "public-a": "rtbassoc-0f55cb72f58eba3c6"
    "public-b": "rtbassoc-0e260598fc03c1bda"
    "public-c": "rtbassoc-0ed529b17080a7ff5"
    "private-a": "rtbassoc-05a8500db23f7e5c4"
    "private-b": "rtbassoc-04181252701b445f0"
    "private-c": "rtbassoc-0f81cf5c3e798aa8c"
}

# =============================================================================
# E2E Test Definition
# =============================================================================

# Foundation manifest as untyped dict (bypasses KCL schema validation for pass-through fields)
_foundation_manifest = {
    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
    kind: "Foundation"
    metadata: {
        name: _foundation_name
        namespace: "default"
    }
    spec: {
        managementPolicies: _observeOnly

        providerConfigRef: {
            name: "default"
            kind: "ProviderConfig"
        }
        kubernetesProviderConfigRef: {
            name: _foundation_name
            kind: "ProviderConfig"
        }
        region: _region

        memberAccountsProviderConfigs: {
            managementPolicies: ["*"]
        }

        tags: {
            "e2etest": "true"
            "managed-by": "crossplane"
        }

        # -----------------------------------------------------------------
        # Organization - import existing org, OU, and account
        # -----------------------------------------------------------------
        organization: {
            externalName: _existing_org_id
            managementPolicies: _observeOnly
            awsServiceAccessPrincipals: [
                "iam.amazonaws.com"
                "sso.amazonaws.com"
                "account.amazonaws.com"
            ]
        }

        organizationalUnits: [
            {
                path: _test_ou_path
                externalName: _test_ou_external_name
                managementPolicies: _observeOnly
            }
        ]

        accounts: [
            {
                name: _test_account_name
                email: _test_account_email
                ou: _test_ou_path
                externalName: _test_account_external_name
                managementPolicies: _observeOnly
            }
        ]

        # -----------------------------------------------------------------
        # Identity Center - import existing
        # -----------------------------------------------------------------
        identityCenter: {
            region: _region
            identityStoreId: _identity_store_id
            instanceArn: _instance_arn
            sessionDuration: "PT4H"

            groups: [
                {
                    name: _persistent_group_name
                    displayName: "E2E Test Group"
                    externalName: _persistent_group_id
                    managementPolicies: _observeOnly
                }
            ]

            permissionSets: [
                {
                    name: _persistent_permission_set_name
                    description: "E2E testing read-only access"
                    externalName: _persistent_permission_set_external_name
                    managementPolicies: _observeOnly
                    managedPolicies: [
                        "arn:aws:iam::aws:policy/ReadOnlyAccess"
                    ]
                    assignToGroups: [_persistent_group_name]
                    # Use account name - Foundation resolves to account ID
                    assignToAccounts: [_test_account_name]
                }
            ]
        }

        # -----------------------------------------------------------------
        # IPAM - import existing from aws-ipam e2e test
        # -----------------------------------------------------------------
        # Foundation imports the full pool hierarchy so networks can
        # reference pools by name via poolRef without knowing pool IDs.
        ipam: {
            enabled: True
            region: _region
            operatingRegions: [_region]
            managementPolicies: _observeOnly
            externalName: _ipam_external_name

            pools: {
                ipv4: [
                    # Global IPv4 pool - top of hierarchy
                    {
                        name: "ipv4"
                        region: _region
                        cidr: "10.0.0.0/8"
                        managementPolicies: _observeOnly
                        externalName: _ipv4_global_pool_external_name
                        cidrExternalName: _ipv4_global_cidr_external_name
                        allocations: {
                            netmaskLength: {
                                default: 12
                                min: 12
                                max: 12
                            }
                        }
                        description: "Global IPv4 pool (/8, allocates /12 regional pools)"
                    },
                    # Regional IPv4 pool - us-east-2 (child of global)
                    # Networks reference this via poolRef: "ipv4-us-east-2"
                    {
                        name: "ipv4-us-east-2"
                        sourcePoolRef: "ipv4"
                        region: _region
                        locale: _region
                        cidr: "10.0.0.0/12"
                        managementPolicies: _observeOnly
                        externalName: _ipv4_regional_pool_external_name
                        cidrExternalName: _ipv4_regional_cidr_external_name
                        allocations: {
                            netmaskLength: {
                                default: 16
                                min: 16
                                max: 16
                            }
                        }
                        description: "Regional IPv4 pool for us-east-2 (/12, allocates /16 VPCs)"
                    }
                ]
                ipv6: {
                    ula: [
                        # Global IPv6 private pool - ULA /32
                        {
                            name: "ipv6-private"
                            region: _region
                            locale: _region
                            netmaskLength: 32
                            managementPolicies: _observeOnly
                            externalName: _ipv6_private_pool_external_name
                            cidrExternalName: _ipv6_private_cidr_external_name
                            allocations: {
                                netmaskLength: {
                                    default: 48
                                    min: 48
                                    max: 48
                                }
                            }
                            description: "Global IPv6 private pool (ULA /32, allocates /48 regional pools)"
                        },
                        # Regional IPv6 private pool - us-east-2 (child of global)
                        # Networks reference this via poolRef: "ipv6-private-us-east-2"
                        {
                            name: "ipv6-private-us-east-2"
                            sourcePoolRef: "ipv6-private"
                            region: _region
                            locale: _region
                            netmaskLength: 48
                            managementPolicies: _observeOnly
                            externalName: _ipv6_private_regional_pool_external_name
                            cidrExternalName: _ipv6_private_regional_cidr_external_name
                            allocations: {
                                netmaskLength: {
                                    default: 56
                                    min: 56
                                    max: 56
                                }
                            }
                            description: "Regional IPv6 private pool for us-east-2 (/48, allocates /56 VPCs)"
                        }
                    ]
                }
            }
        }

        # -----------------------------------------------------------------
        # Networks - import existing from aws-network e2e test
        # -----------------------------------------------------------------
        # Networks reference IPAM pools by name via poolRef.
        # Foundation resolves poolRef to poolId from IPAM status.
        networks: [
            {
                name: "e2etest-network"
                region: _region
                # No account specified = uses management account (spec.providerConfigRef)
                managementPolicies: _observeOnly

                # Reference regional pools by name - Foundation resolves to pool IDs
                ipam: {
                    ipv4: {
                        poolRef: "ipv4-us-east-2"
                        netmaskLength: 16
                    }
                    ipv6Ula: {
                        poolRef: "ipv6-private-us-east-2"
                        netmaskLength: 56
                    }
                }

                # VPC import
                vpc: {
                    externalName: _network_vpc_external_name
                }

                # Internet Gateway import
                internetGateway: {
                    externalName: _network_igw_external_name
                }

                # Egress-Only Internet Gateway import (for IPv6)
                egressOnlyInternetGateway: {
                    externalName: _network_eigw_external_name
                }

                # Subnet layout with imports
                subnetLayout: {
                    availabilityZones: ["a", "b", "c"]
                    public: {
                        enabled: True
                        netmaskLength: 24
                    }
                    private: {
                        enabled: True
                        netmaskLength: 20
                    }
                    externalNames: _network_subnet_external_names
                }

                # Route tables import
                routeTables: {
                    externalNames: _network_rt_external_names
                    associationExternalNames: _network_rta_external_names
                }

                # No NAT gateway (persistent network doesn't have one)
                nat: {
                    enabled: False
                }
            }
        ]
    }
}

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [_foundation_manifest]
            extraResources: [
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata: {
                        name: "aws-creds"
                        namespace: "default"
                    }
                    data: {
                        creds: _base64_creds
                    }
                },
                {
                    apiVersion: "aws.m.upbound.io/v1beta1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: "default"
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "Secret"
                            secretRef: {
                                namespace: "default"
                                name: "aws-creds"
                                key: "creds"
                            }
                        }
                    }
                },
                # Kubernetes ProviderConfig for account ProviderConfig Objects
                # Uses InjectedIdentity for in-cluster access
                {
                    apiVersion: "kubernetes.m.crossplane.io/v1alpha1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: _foundation_name
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "InjectedIdentity"
                        }
                    }
                },
                # DeploymentRuntimeConfig for Kubernetes provider with known SA name
                {
                    apiVersion: "pkg.crossplane.io/v1beta1"
                    kind: "DeploymentRuntimeConfig"
                    metadata: {
                        name: "crossplane-contrib-provider-kubernetes"
                    }
                    spec: {
                        serviceAccountTemplate: {
                            metadata: {
                                name: "crossplane-contrib-provider-kubernetes"
                            }
                        }
                    }
                },
                # ServiceAccount for Kubernetes provider
                {
                    apiVersion: "v1"
                    kind: "ServiceAccount"
                    metadata: {
                        name: "crossplane-contrib-provider-kubernetes"
                        namespace: "crossplane-system"
                    }
                },
                # ClusterRoleBinding granting cluster-admin to the K8s provider SA
                {
                    apiVersion: "rbac.authorization.k8s.io/v1"
                    kind: "ClusterRoleBinding"
                    metadata: {
                        name: "crossplane-contrib-provider-kubernetes-admin"
                    }
                    roleRef: {
                        apiGroup: "rbac.authorization.k8s.io"
                        kind: "ClusterRole"
                        name: "cluster-admin"
                    }
                    subjects: [
                        {
                            kind: "ServiceAccount"
                            name: "crossplane-contrib-provider-kubernetes"
                            namespace: "crossplane-system"
                        }
                    ]
                },
                # Provider with runtimeConfigRef to use our DeploymentRuntimeConfig
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata: {
                        name: "crossplane-contrib-provider-kubernetes"
                    }
                    spec: {
                        package: "xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v1.1.0"
                        runtimeConfigRef: {
                            name: "crossplane-contrib-provider-kubernetes"
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 4500
        }
    }
]
items = _items
