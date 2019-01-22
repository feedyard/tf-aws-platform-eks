# feedyard/tf-aws-platform-eks

Terraform module to create eks cluster in platform-vpc space.


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| cluster\_create\_security\_group | ========these are set to the expected platform sandbox environment settingsWhether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`. | string | `true` | no |
| cluster\_create\_timeout | Timeout value when creating the EKS cluster. | string | `15m` | no |
| cluster\_delete\_timeout | Timeout value when deleting the EKS cluster. | string | `15m` | no |
| cluster\_name | ================================================================platform cluster name (e.g., prod-na1) | string | - | yes |
| cluster\_security\_group\_id | If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32. | string | `` | no |
| cluster\_version | ekse cluster version | string | `1.11` | no |
| cluster\_vpc\_id | platform-vpc id | string | - | yes |
| cluster\_vpc\_subnet\_ids | platform-vpc subnets. subnet-public and subnet-private ids | list | - | yes |
| tags | A map of tags to add to all resources | map | `{}` | no |
| worker\_additional\_security\_group\_ids | list of additional security group ids to include in worker launch config | list | `true` | no |
| worker\_create\_security\_group | ================worker node infoWhether to create a security group for the workers or attach the workers to `worker_security_group_id`. | string | `true` | no |
| worker\_group\_count | The number of maps contained within the worker_groups list. | string | `1` | no |
| worker\_group\_launch\_template\_count | The number of maps contained within the worker_groups_launch_template list. | string | `0` | no |
| worker\_groups | A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys. | list | `[ { "name": "default" } ]` | no |
| worker\_groups\_launch\_template | A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys. | list | `[ { "name": "default" } ]` | no |
| worker\_security\_group\_id | If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster. | string | `` | no |
| worker\_sg\_ingress\_from\_port | Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80). | string | `1025` | no |
| workers\_group\_defaults | Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys. | map | `{}` | no |
| workers\_group\_launch\_template\_defaults | Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys. | map | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_arn | The Amazon Resource Name (ARN) of the cluster |
| cluster\_certificate\_authority | Nested attribute containing certificate-authority-data for the cluster |
| cluster\_endpoint | endpoint for your Kubernetes API server |
| cluster\_id | cluster id |
| cluster\_platform\_version | platform version for the cluster |
| cluster\_security\_group\_id | Security group ID attached to the EKS cluster. |
| cluster\_version | Kubernetes server version for the cluster |
| cluster\_vpc\_config | Additional nested attributes |
| worker\_security\_group\_id | Security group ID attached to the EKS workers. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
inspired by https://github.com/terraform-aws-modules/terraform-aws-eks