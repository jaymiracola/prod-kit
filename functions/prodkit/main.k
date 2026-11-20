
import models.io.upbound.customer.v1alpha1 as customerv1alpha1
import models.io.upbound.gcp.cloudrun.v1beta1 as cloudrunv1beta1
import models.io.upbound.gcp.cloudrun.v1beta2 as cloudrunv1beta2
import models.io.upbound.gcp.sql.v1beta1 as sqlv1beta1
import models.io.upbound.gcp.sql.v1beta2 as sqlv1beta2
import models.io.upbound.gcp.v1alpha1 as gcpv1alpha1
import models.io.upbound.gcp.v1beta1 as gcpv1beta1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.upbound.gcp.redis.v1beta2 as gcpredisv1beta2

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
  {
    name = name
    annotations = {
      "krm.kcl.dev/composition-resource-name" = name
    }
  }
}

serviceName = "{}-service".format(oxr.metadata.name)

_items: [any] = [
    cloudrunv1beta2.V2Service {
        apiVersion: "cloudrun.gcp.upbound.io/v1beta2"
        kind: "V2Service"
        metadata: _metadata("{}-run".format(oxr.metadata.name))
        spec: {
            forProvider: {
                ingress: "INGRESS_TRAFFIC_ALL"
                location: "us-central1"
                template: {
                    containers: [
                        {
                            image: oxr.spec.parameters.image
                        }
                    ]
                }
            }
        }
    }
]
_items += [
  cloudrunv1beta2.ServiceIAMMember {
    metadata: _metadata("{}-run-invoker".format(oxr.metadata.name))
    spec: {
      forProvider: {
        project:   oxr.spec.parameters.project    # your GCP project
        location:  "us-central1"
        service:   "{}-run".format(oxr.metadata.name)
        role:      "roles/run.invoker"
        member:    "allUsers"
      }
    }
  }
]

if oxr.spec.parameters.db == True:
    _items += [
        sqlv1beta2.DatabaseInstance {
            apiVersion: "sql.gcp.upbound.io/v1beta2"
            kind: "DatabaseInstance"
            metadata: _metadata("{}-db".format(oxr.metadata.name))
            spec: {
                forProvider: {
                    databaseVersion: "MYSQL_5_7"
                    deletionProtection: False
                    region: "us-central1"
                    settings: {
                        diskSize: 20
                        tier: "db-f1-micro"
                    }
                }
                writeConnectionSecretToRef: {
                    name: serviceName + "-sql"
                    namespace: "upbound-system"
                }
            }
        }
    ]

if oxr.spec.parameters.cache == True:
    _items += [
        gcpredisv1beta2.Instance{
            apiVersion: "redis.gcp.upbound.io/v1beta2"
            kind: "Instance"
            metadata: _metadata("{}-redis".format(oxr.metadata.name))
            spec: {
                forProvider: {
                    authEnabled: True
                    memorySizeGb: 1
                    tier: "STANDARD_HA"
                    region: "us-central1"
                }
                writeConnectionSecretToRef: {
                    name: serviceName + "-redis"
                    namespace: "upbound-system"
                }
            }
        }
    ]
items = _items

