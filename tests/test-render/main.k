import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# =============================================================================
# Unit Tests for Foundation XRD
# =============================================================================
# These tests focus on behavioral validation of the Foundation XRD's API.
# render/validate already checks that composed resources have valid schemas.
# These tests verify YOUR API produces expected behavior:
# - Conditional rendering (when flag X is set, resources render)
# - Configuration mapping (when flag Y is set, resource configured correctly)
# - Default values (when field Z is omitted, defaults applied)
# - Edge cases (when A and B interact, expected output)

_items = [
    # =========================================================================
    # Conditional Rendering: Identity Center
    # =========================================================================
    # When identityCenter.identityStoreId is set, IdentityCenter XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-identity-center-renders-when-configured"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-ic"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                        groups = [{name = "Admins", description = "Admin group"}]
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-ic-identity-center"
                    spec.identityStoreId = "d-test123"
                }
            ]
        }
    },

    # =========================================================================
    # Conditional Rendering: IPAM
    # =========================================================================
    # When ipam.pools are defined, IPAM XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-ipam-renders-when-pools-defined"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-ipam"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    ipam = {
                        operatingRegions = ["us-east-1"]
                        pools = {
                            ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata.name = "test-ipam-ipam"
                    spec.operatingRegions = ["us-east-1"]
                }
            ]
        }
    },

    # =========================================================================
    # Conditional Rendering: Organization
    # =========================================================================
    # When organizationalUnits are defined, Organization XRD is rendered

    metav1alpha1.CompositionTest{
        metadata.name = "test-organization-renders-when-ous-defined"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-org"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    organizationalUnits = [{path = "TestOU"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata.name = "test-org"
                }
            ]
        }
    },

    # =========================================================================
    # Default Values: Region defaults to us-east-1
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-region-defaults-to-us-east-1"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-defaults"
                spec = {
                    managementPolicies = ["*"]
                    # region is omitted - should default to us-east-1
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-defaults-identity-center"
                    spec.region = "us-east-1"
                }
            ]
        }
    },

    # =========================================================================
    # Default Values: managed tags always applied
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-default-hops-tag-applied"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-tags"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    tags = {"custom-tag" = "custom-value"}
                    organizationalUnits = [{path = "Test"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata.name = "test-tags"
                    spec.tags = {
                        "hops.ops.com.ai/managed" = "true"
                        "hops.ops.com.ai/foundation" = "test-tags"
                        "custom-tag" = "custom-value"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: Account names resolved to IDs
    # =========================================================================
    # When Organization status has accounts, permission set assignToAccounts
    # resolves account names to account IDs

    metav1alpha1.CompositionTest{
        metadata.name = "test-account-names-resolved-to-ids"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-resolve"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    organizationalUnits = [{path = "Teams"}]
                    accounts = [{name = "team-alpha", email = "alpha@test.com", ou = "Teams"}]
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                        groups = [{name = "TeamAlpha"}]
                        permissionSets = [{
                            name = "AlphaAccess"
                            managedPolicies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
                            assignToGroups = ["TeamAlpha"]
                            assignToAccounts = ["team-alpha"]
                        }]
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata = {
                        name = "test-resolve"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "organization"
                        }
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        accounts = [{name = "team-alpha", id = "123456789012", ready = True}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-resolve-identity-center"
                    spec.permissionSets = [{
                        name = "AlphaAccess"
                        assignToAccounts = ["123456789012"]
                    }]
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: ProviderConfigRef inheritance
    # =========================================================================
    # Child XRDs inherit providerConfigRef from Foundation

    metav1alpha1.CompositionTest{
        metadata.name = "test-provider-config-inherited"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-provider"
                spec = {
                    managementPolicies = ["*"]
                    providerConfigRef = {
                        name = "custom-provider"
                        kind = "ProviderConfig"
                    }
                    region = "us-west-2"
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-provider-identity-center"
                    spec.providerConfigRef = {
                        name = "custom-provider"
                        kind = "ProviderConfig"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Configuration Mapping: memberAccountsProviderConfigs.managementPolicies
    # =========================================================================
    # Account ProviderConfig Objects get their own managementPolicies

    metav1alpha1.CompositionTest{
        metadata.name = "test-account-providerconfigs-management-policies"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = False  # Uses Kubernetes Object which may not validate
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-mgmt"
                spec = {
                    managementPolicies = ["Observe"]
                    region = "us-east-1"
                    memberAccountsProviderConfigs = {
                        managementPolicies = ["*"]
                    }
                    organizationalUnits = [{path = "Test"}]
                    accounts = [{name = "test-account", email = "test@example.com", ou = "Test"}]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Organization"
                    metadata = {
                        name = "test-mgmt"
                        annotations = {"crossplane.io/composition-resource-name" = "organization"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        accounts = [{name = "test-account", id = "222222222222", ready = True}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "test-mgmt-pc-test-account"
                    spec.managementPolicies = ["*"]
                }
            ]
        }
    },

    # =========================================================================
    # Edge Case: Networks don't render until IPAM pools are resolved
    # =========================================================================
    # Networks with poolRef wait for IPAM status to provide pool IDs

    metav1alpha1.CompositionTest{
        metadata.name = "test-networks-wait-for-ipam-pool-ids"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-net"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    ipam = {
                        pools = {
                            ipv4 = [{name = "ipv4-pool", cidr = "10.0.0.0/8"}]
                        }
                    }
                    networks = [{
                        name = "main"
                        region = "us-east-1"
                        ipam = {ipv4 = {poolRef = "ipv4-pool", netmaskLength = 16}}
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-net-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools = {
                            ipv4 = [{name = "ipv4-pool", id = "ipam-pool-abc123"}]
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-net-main"
                    spec.ipam.ipv4.poolId = "ipam-pool-abc123"
                }
            ]
        }
    },

    # =========================================================================
    # Merge Precedence: Network-specific subnetLayout overrides networkDefaults
    # =========================================================================
    # When networkDefaults.subnetLayout and network.subnetLayout both have values,
    # network-specific values should win (merge gives precedence to last arg)

    metav1alpha1.CompositionTest{
        metadata.name = "test-network-subnetlayout-overrides-defaults"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-subnet"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    networkDefaults = {
                        subnetLayout = {
                            availabilityZones = ["a", "b"]
                            public = {enabled = True, netmaskLength = 24}
                            private = {enabled = True, netmaskLength = 20}
                        }
                    }
                    ipam.pools.ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                    networks = [{
                        name = "main"
                        region = "us-east-1"
                        ipam.ipv4 = {poolRef = "test-pool", netmaskLength = 16}
                        # Override: use 3 AZs and different netmask
                        subnetLayout = {
                            availabilityZones = ["a", "b", "c"]
                            public = {netmaskLength = 28}
                        }
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-subnet-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools.ipv4 = [{name = "test-pool", id = "ipam-pool-123"}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-subnet-main"
                    # Network-specific values should override defaults
                    spec.subnetLayout = {
                        availabilityZones = ["a", "b", "c"]
                        public = {enabled = True, netmaskLength = 28}
                        private = {enabled = True, netmaskLength = 20}
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Merge Precedence: Network-specific nat overrides networkDefaults
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-network-nat-overrides-defaults"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-nat"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    networkDefaults = {
                        nat = {
                            enabled = True
                            strategy = "SingleAz"
                        }
                    }
                    ipam.pools.ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                    networks = [{
                        name = "ha-network"
                        region = "us-east-1"
                        ipam.ipv4 = {poolRef = "test-pool", netmaskLength = 16}
                        # Override: use HighlyAvailable strategy
                        nat = {strategy = "HighlyAvailable"}
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-nat-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools.ipv4 = [{name = "test-pool", id = "ipam-pool-456"}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-nat-ha-network"
                    # Network-specific strategy should override default
                    spec.nat = {
                        enabled = True
                        strategy = "HighlyAvailable"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Merge Precedence: Network-specific flowLogs overrides networkDefaults
    # =========================================================================

    metav1alpha1.CompositionTest{
        metadata.name = "test-network-flowlogs-overrides-defaults"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-flow"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    networkDefaults = {
                        flowLogs = {
                            enabled = True
                            destination = "cloudwatch"
                            trafficType = "ALL"
                        }
                    }
                    ipam.pools.ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                    networks = [{
                        name = "s3-logs"
                        region = "us-east-1"
                        ipam.ipv4 = {poolRef = "test-pool", netmaskLength = 16}
                        # Override: use S3 destination and only REJECT traffic
                        flowLogs = {
                            destination = "s3"
                            trafficType = "REJECT"
                        }
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-flow-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools.ipv4 = [{name = "test-pool", id = "ipam-pool-789"}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-flow-s3-logs"
                    # Network-specific values should override defaults
                    spec.flowLogs = {
                        enabled = True
                        destination = "s3"
                        trafficType = "REJECT"
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Merge Precedence: Tags merge correctly (spec -> networkDefaults -> network)
    # =========================================================================
    # Tags should merge: spec.tags first, then networkDefaults.tags, then
    # network-specific tags. Network-specific tags should win for conflicts.

    metav1alpha1.CompositionTest{
        metadata.name = "test-network-tags-merge-precedence"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-tags-merge"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    # Level 1: spec.tags (lowest priority)
                    tags = {
                        "environment" = "production"
                        "team" = "platform"
                        "cost-center" = "shared"
                    }
                    networkDefaults = {
                        # Level 2: networkDefaults.tags (medium priority)
                        tags = {
                            "team" = "networking"
                            "layer" = "network"
                        }
                    }
                    ipam.pools.ipv4 = [{name = "test-pool", cidr = "10.0.0.0/8"}]
                    networks = [{
                        name = "app-vpc"
                        region = "us-east-1"
                        ipam.ipv4 = {poolRef = "test-pool", netmaskLength = 16}
                        # Level 3: network-specific tags (highest priority)
                        tags = {
                            "team" = "application"
                            "app" = "myapp"
                        }
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IPAM"
                    metadata = {
                        name = "test-tags-merge-ipam"
                        annotations = {"crossplane.io/composition-resource-name" = "ipam"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        pools.ipv4 = [{name = "test-pool", id = "ipam-pool-tags"}]
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "Network"
                    metadata.name = "test-tags-merge-app-vpc"
                    spec.tags = {
                        # From spec.tags (not overridden)
                        "environment" = "production"
                        "cost-center" = "shared"
                        # From networkDefaults.tags (not overridden by network)
                        "layer" = "network"
                        # From network.tags (highest priority wins)
                        "team" = "application"
                        "app" = "myapp"
                        # Default managed tags
                        "hops.ops.com.ai/managed" = "true"
                        "hops.ops.com.ai/foundation" = "test-tags-merge"
                    }
                }
            ]
        }
    }
]

items = _items
