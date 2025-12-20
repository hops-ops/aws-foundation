# e2etest-aws-foundation - Import existing Organization, Identity Center and IPAM
# ================================================================================
# Tests Foundation's ability to import existing AWS resources via pass-through.
# This test imports:
# - Existing AWS Organization (with OUs and accounts)
# - Existing Identity Center instance (with groups and permission sets)
# - Existing IPAM (with pools)
#
# All persisted resources use managementPolicies without Delete to preserve them.
# Prerequisite: Run aws-ipam e2e test first to create the IPAM resources.
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

# Existing pools to import
_ipv4_pool_external_name = "ipam-pool-0a82c73b97dc0dabb"
_ipv4_cidr_external_name = "10.0.0.0/8" + "_" + _ipv4_pool_external_name

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

        aws: {
            providerConfig: "default"
            region: _region
        }

        k8s: {
            providerConfig: _foundation_name
        }

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
        ipam: {
            enabled: True
            scope: "private"
            homeRegion: _region
            operatingRegions: [_region]
            managementPolicies: _observeOnly
            externalName: _ipam_external_name

            pools: [
                # Import existing IPv4 pool
                {
                    name: "ipv4"
                    addressFamily: "ipv4"
                    region: _region
                    cidr: "10.0.0.0/8"
                    managementPolicies: _observeOnly
                    externalName: _ipv4_pool_external_name
                    cidrExternalName: _ipv4_cidr_external_name
                    allocationDefaultNetmaskLength: 20
                    allocationMinNetmaskLength: 16
                    allocationMaxNetmaskLength: 24
                    description: "IPv4 pool for VPCs"
                }
            ]
        }
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
