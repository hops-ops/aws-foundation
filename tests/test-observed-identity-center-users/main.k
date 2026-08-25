import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# IdentityCenter reports users as {name, id}. Foundation must consume that
# child status contract on subsequent reconciliations.
_items = [
    metav1alpha1.CompositionTest{
        metadata.name = "test-identity-center-observed-users-use-status-name"
        spec = {
            compositionPath = "apis/foundations/composition.yaml"
            xrdPath = "apis/foundations/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "Foundation"
                metadata.name = "test-observed-users"
                spec = {
                    managementPolicies = ["*"]
                    region = "us-east-1"
                    identityCenter = {
                        identityStoreId = "d-test123"
                        instanceArn = "arn:aws:sso:::instance/ssoins-test"
                        groups = [{name = "Admins"}]
                        users = [{
                            username = "patrick@example.com"
                            email = "patrick@example.com"
                            groups = ["Admins"]
                            groupMembershipExternalNames = {
                                Admins = "membership-123"
                            }
                        }]
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata = {
                        name = "test-observed-users-identity-center"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "identity-center"
                        }
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        identityStore = {
                            id = "d-test123"
                            groups = [{
                                name = "Admins"
                                id = "d-test123/group-123"
                            }]
                            users = [{
                                name = "patrick@example.com"
                                id = "d-test123/user-123"
                            }]
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "IdentityCenter"
                    metadata.name = "test-observed-users-identity-center"
                    spec.users = [{
                        username = "patrick@example.com"
                        email = "patrick@example.com"
                        groups = ["Admins"]
                        groupMembershipExternalNames = {
                            Admins = "membership-123"
                        }
                    }]
                }
            ]
        }
    }
]

items = _items
