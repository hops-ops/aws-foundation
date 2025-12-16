import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

_items = [
    # =========================================================================
    # Individual Example Tests
    # =========================================================================
    # Tests for single-account foundation without Organization

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-individual-identity-center"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/individual.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # Identity Center Groups
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "my-foundation-group-administrators"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                        }
                        forProvider: {
                            displayName: "Administrators"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "my-foundation-group-developers"
                    }
                    spec: {
                        providerConfigRef: {
                            name: "default"
                        }
                        forProvider: {
                            displayName: "Developers"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "my-foundation-group-readonly"
                    }
                    spec: {
                        forProvider: {
                            displayName: "ReadOnly"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                # Permission Sets
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "my-foundation-ps-administratoraccess"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                        }
                        forProvider: {
                            name: "AdministratorAccess"
                            instanceArn: "arn:aws:sso:::instance/ssoins-abcdef0123456789"
                            sessionDuration: "PT4H"
                            region: "us-east-1"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "my-foundation-ps-poweruseraccess"
                    }
                    spec: {
                        forProvider: {
                            name: "PowerUserAccess"
                            instanceArn: "arn:aws:sso:::instance/ssoins-abcdef0123456789"
                            sessionDuration: "PT8H"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "my-foundation-ps-viewonlyaccess"
                    }
                    spec: {
                        forProvider: {
                            name: "ViewOnlyAccess"
                            sessionDuration: "PT1H"
                        }
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
                # IPAM Instance
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpam"
                    metadata: {
                        name: "my-foundation-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                        }
                        forProvider: {
                            region: "us-east-1"
                            tags: {
                                hops: "true"
                                "managed-by": "crossplane"
                            }
                        }
                    }
                },
                # IPAM Private Scope
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamScope"
                    metadata: {
                        name: "my-foundation-ipam-private"
                    }
                    spec: {
                        forProvider: {
                            ipamIdRef: {
                                name: "my-foundation-ipam"
                            }
                            region: "us-east-1"
                        }
                    }
                },
                # IPAM Public Scope (for IPv6 public pools)
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamScope"
                    metadata: {
                        name: "my-foundation-ipam-public"
                    }
                    spec: {
                        forProvider: {
                            ipamIdRef: {
                                name: "my-foundation-ipam"
                            }
                        }
                    }
                },
                # IPv4 Pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "my-foundation-ipv4"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeIdRef: {
                                name: "my-foundation-ipam-private"
                            }
                            locale: "us-east-1"
                            region: "us-east-1"
                            allocationDefaultNetmaskLength: 20
                            allocationMinNetmaskLength: 16
                            allocationMaxNetmaskLength: 24
                        }
                    }
                },
                # IPv4 Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "my-foundation-ipv4-cidr"
                    }
                    spec: {
                        forProvider: {
                            cidr: "10.0.0.0/8"
                            ipamPoolIdRef: {
                                name: "my-foundation-ipv4"
                            }
                        }
                    }
                },
                # IPv6 Public Pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "my-foundation-ipv6-public"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            ipamScopeIdRef: {
                                name: "my-foundation-ipam-public"
                            }
                            publicIpSource: "amazon"
                            awsService: "ec2"
                            allocationDefaultNetmaskLength: 56
                            allocationMinNetmaskLength: 52
                            allocationMaxNetmaskLength: 60
                        }
                    }
                },
                # IPv6 Private Pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "my-foundation-ipv6-private"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            ipamScopeIdRef: {
                                name: "my-foundation-ipam-private"
                            }
                            allocationDefaultNetmaskLength: 56
                            allocationMinNetmaskLength: 48
                            allocationMaxNetmaskLength: 64
                        }
                    }
                },
                # IPv6 Private Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "my-foundation-ipv6-private-cidr"
                    }
                    spec: {
                        forProvider: {
                            cidr: "fd00:my:app::/48"
                            ipamPoolIdRef: {
                                name: "my-foundation-ipv6-private"
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
                # Organization
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "Organization"
                    metadata: {
                        name: "acme"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "aws-management-account"
                        }
                        forProvider: {
                            featureSet: "ALL"
                            enabledPolicyTypes: [
                                "SERVICE_CONTROL_POLICY",
                                "TAG_POLICY",
                                "BACKUP_POLICY",
                                "AISERVICES_OPT_OUT_POLICY"
                            ]
                            awsServiceAccessPrincipals: [
                                "sso.amazonaws.com",
                                "ipam.amazonaws.com",
                                "ram.amazonaws.com"
                            ]
                        }
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
                # Identity Center Groups
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "acme-group-administrators"
                    }
                    spec: {
                        providerConfigRef: {
                            name: "aws-management-account"
                        }
                        forProvider: {
                            displayName: "Administrators"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "acme-group-developers"
                    }
                    spec: {
                        forProvider: {
                            displayName: "Developers"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "acme-group-readonly"
                    }
                    spec: {
                        forProvider: {
                            displayName: "ReadOnly"
                            identityStoreId: "d-1234567890"
                        }
                    }
                },
                # Permission Sets
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "acme-ps-administratoraccess"
                    }
                    spec: {
                        forProvider: {
                            name: "AdministratorAccess"
                            instanceArn: "arn:aws:sso:::instance/ssoins-abcdef0123456789"
                            sessionDuration: "PT4H"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "acme-ps-developeraccess"
                    }
                    spec: {
                        forProvider: {
                            name: "DeveloperAccess"
                            instanceArn: "arn:aws:sso:::instance/ssoins-abcdef0123456789"
                            sessionDuration: "PT8H"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "acme-ps-viewonlyaccess"
                    }
                    spec: {
                        forProvider: {
                            name: "ViewOnlyAccess"
                            sessionDuration: "PT1H"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Step 1: Organization Ready
    # =========================================================================
    # Tests OUs and Identity Center groups after Organization is ready

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-step-1-ous"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
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
                        atProvider: {
                            id: "o-acme12345"
                            masterAccountId: "111111111111"
                            roots: [{id: "r-acme"}]
                        }
                    }
                }
            ]
            assertResources: [
                # OUs created after Organization is ready
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-security"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            name: "Security"
                            parentId: "r-acme"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-infrastructure"
                    }
                    spec: {
                        forProvider: {
                            name: "Infrastructure"
                            parentId: "r-acme"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-workloads"
                    }
                    spec: {
                        forProvider: {
                            name: "Workloads"
                            parentId: "r-acme"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-sandbox"
                    }
                    spec: {
                        forProvider: {
                            name: "Sandbox"
                            parentId: "r-acme"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Step 2: OUs Ready
    # =========================================================================
    # Tests nested OUs and Accounts after parent OUs are ready

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-step-2-nested-ous-and-accounts"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
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
                        atProvider: {
                            id: "o-acme12345"
                            masterAccountId: "111111111111"
                            roots: [{id: "r-acme"}]
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-security"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "ou-security"
                            "crossplane.io/composition-resource-name": "ou-security"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {id: "ou-acme-security"}
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-infrastructure"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "ou-infrastructure"
                            "crossplane.io/composition-resource-name": "ou-infrastructure"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {id: "ou-acme-infrastructure"}
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-workloads"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "ou-workloads"
                            "crossplane.io/composition-resource-name": "ou-workloads"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {id: "ou-acme-workloads"}
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-sandbox"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "ou-sandbox"
                            "crossplane.io/composition-resource-name": "ou-sandbox"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {id: "ou-acme-sandbox"}
                    }
                }
            ]
            assertResources: [
                # Nested OUs (Workloads/Prod and Workloads/Non-Prod)
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-workloads-prod"
                    }
                    spec: {
                        forProvider: {
                            name: "Prod"
                            parentId: "ou-acme-workloads"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-workloads-non-prod"
                    }
                    spec: {
                        forProvider: {
                            name: "Non-Prod"
                            parentId: "ou-acme-workloads"
                        }
                    }
                },
                # Accounts created in their respective OUs
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "Account"
                    metadata: {
                        name: "acme-acme-security-tooling"
                    }
                    spec: {
                        forProvider: {
                            email: "security-tooling@acme.example.com"
                            name: "acme-security-tooling"
                            parentId: "ou-acme-security"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "Account"
                    metadata: {
                        name: "acme-acme-shared-services"
                    }
                    spec: {
                        forProvider: {
                            email: "shared-services@acme.example.com"
                            name: "acme-shared-services"
                            parentId: "ou-acme-infrastructure"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Step 3: Full OUs + Accounts Ready
    # =========================================================================
    # Tests delegated administrators after accounts are ready

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-step-3-delegated-admins"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
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
                        atProvider: {
                            id: "o-acme12345"
                            masterAccountId: "111111111111"
                            roots: [{id: "r-acme"}]
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "OrganizationalUnit"
                    metadata: {
                        name: "acme-ou-infrastructure"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "ou-infrastructure"
                            "crossplane.io/composition-resource-name": "ou-infrastructure"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {id: "ou-acme-infrastructure"}
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "Account"
                    metadata: {
                        name: "acme-acme-shared-services"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "account-acme-shared-services"
                            "crossplane.io/composition-resource-name": "account-acme-shared-services"
                        }
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}]
                        atProvider: {
                            id: "333333333333"
                        }
                    }
                }
            ]
            assertResources: [
                # Delegated Administrators - naming format: {foundation}-da-{accountName}-{servicePrincipal-slug}
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "DelegatedAdministrator"
                    metadata: {
                        name: "acme-da-acme-shared-services-sso-amazonaws-com"
                    }
                    spec: {
                        forProvider: {
                            servicePrincipal: "sso.amazonaws.com"
                        }
                    }
                },
                {
                    apiVersion: "organizations.aws.m.upbound.io/v1beta1"
                    kind: "DelegatedAdministrator"
                    metadata: {
                        name: "acme-da-acme-shared-services-ipam-amazonaws-com"
                    }
                    spec: {
                        forProvider: {
                            servicePrincipal: "ipam.amazonaws.com"
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - IPAM Tests
    # =========================================================================
    # Tests IPAM configuration with dual-stack pools

    metav1alpha1.CompositionTest{
        metadata.name: "test-foundation-enterprise-ipam"
        spec = {
            compositionPath: "apis/foundations/composition.yaml"
            xrPath: "examples/foundations/enterprise.yaml"
            xrdPath: "apis/foundations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # IPAM Instance
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpam"
                    metadata: {
                        name: "acme-ipam"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "aws-management-account"
                        }
                        forProvider: {
                            region: "us-east-1"
                            tags: {
                                hops: "true"
                                organization: "acme"
                                environment: "production"
                                "managed-by": "crossplane"
                            }
                        }
                    }
                },
                # IPAM Scopes
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamScope"
                    metadata: {
                        name: "acme-ipam-private"
                    }
                    spec: {
                        forProvider: {
                            ipamIdRef: {
                                name: "acme-ipam"
                            }
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamScope"
                    metadata: {
                        name: "acme-ipam-public"
                    }
                    spec: {
                        forProvider: {
                            ipamIdRef: {
                                name: "acme-ipam"
                            }
                        }
                    }
                },
                # IPv4 Production Pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "acme-prod-ipv4-us-east-1"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeIdRef: {
                                name: "acme-ipam-private"
                            }
                            allocationDefaultNetmaskLength: 20
                            allocationMinNetmaskLength: 20
                            allocationMaxNetmaskLength: 26
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "acme-prod-ipv4-us-east-1-cidr"
                    }
                    spec: {
                        forProvider: {
                            cidr: "10.0.0.0/12"
                            ipamPoolIdRef: {
                                name: "acme-prod-ipv4-us-east-1"
                            }
                        }
                    }
                },
                # IPv6 Public Pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "acme-prod-ipv6-us-east-1"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            ipamScopeIdRef: {
                                name: "acme-ipam-public"
                            }
                            publicIpSource: "amazon"
                            awsService: "ec2"
                            allocationDefaultNetmaskLength: 56
                            allocationMinNetmaskLength: 52
                            allocationMaxNetmaskLength: 60
                        }
                    }
                },
                # IPv6 Public Pool CIDR (Amazon-provided)
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "acme-prod-ipv6-us-east-1-cidr"
                    }
                    spec: {
                        forProvider: {
                            ipamPoolIdRef: {
                                name: "acme-prod-ipv6-us-east-1"
                            }
                            netmaskLength: 52
                        }
                    }
                },
                # IPv6 Private Pool (ULA)
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "acme-internal-ipv6-us-east-1"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            ipamScopeIdRef: {
                                name: "acme-ipam-private"
                            }
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "acme-internal-ipv6-us-east-1-cidr"
                    }
                    spec: {
                        forProvider: {
                            cidr: "fd00:acme:0::/48"
                            ipamPoolIdRef: {
                                name: "acme-internal-ipv6-us-east-1"
                            }
                        }
                    }
                }
            ]
        }
    },

    # =========================================================================
    # Enterprise Example - Default Tags Test
    # =========================================================================
    # Verify hops=true tag is always applied

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
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpam"
                    metadata: {
                        name: "acme-ipam"
                    }
                    spec: {
                        forProvider: {
                            tags: {
                                hops: "true"
                            }
                        }
                    }
                }
            ]
        }
    }
]
items = _items
