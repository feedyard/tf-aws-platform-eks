# feedyard/tf-aws-platform-eks

Terraform module to create eks cluster in platform-vpc space.


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| cluster\_create\_security\_group | Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`. | string | `true` | no |
| cluster\_create\_timeout | Timeout value when creating the EKS cluster. | string | `15m` | no |
| cluster\_delete\_timeout | Timeout value when deleting the EKS cluster. | string | `15m` | no |
| cluster\_name | Name of the EKS cluster. Also used as a prefix in names of related resources. | string | - | yes |
| cluster\_security\_group\_id | If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32. | string | `` | no |
| cluster\_subnet\_ids | A list of subnets to place the EKS cluster and workers within. | list | - | yes |
| cluster\_version | Kubernetes version to use for the EKS cluster. | string | `1.11` | no |
| cluster\_vpc\_id | VPC where the cluster and workers will be deployed. | string | - | yes |
| config\_output\_path | Where to save the Kubectl config file (if `write_kubeconfig = true`). Should end in a forward slash `/` . | string | `./` | no |
| kubeconfig\_aws\_authenticator\_additional\_args | Any additional arguments to pass to the authenticator such as the role to assume. e.g. ["-r", "MyEksRole"]. | list | `[]` | no |
| kubeconfig\_aws\_authenticator\_command | Command to use to fetch AWS EKS credentials. | string | `aws-iam-authenticator` | no |
| kubeconfig\_aws\_authenticator\_command\_args | Default arguments passed to the authenticator command. Defaults to [token -i $cluster_name]. | list | `[]` | no |
| kubeconfig\_aws\_authenticator\_env\_variables | Environment variables that should be used when executing the authenticator. e.g. { AWS_PROFILE = "eks"}. | map | `{}` | no |
| kubeconfig\_name | Override the default name used for items kubeconfig. | string | `` | no |
| local\_exec\_interpreter | Command to run for local-exec resources. Must be a shell-style interpreter. If you are on Windows Git Bash is a good choice. | list | `[ "/bin/sh", "-c" ]` | no |
| manage\_aws\_auth | Whether to write and apply the aws-auth configmap file. | string | `true` | no |
| map\_accounts | Additional AWS account numbers to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format. | list | `[]` | no |
| map\_accounts\_count | The count of accounts in the map_accounts list. | string | `0` | no |
| map\_roles | Additional IAM roles to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format. | list | `[]` | no |
| map\_roles\_count | The count of roles in the map_roles list. | string | `0` | no |
| map\_users | Additional IAM users to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format. | list | `[]` | no |
| map\_users\_count | The count of roles in the map_users list. | string | `0` | no |
| tags | A map of tags to add to all resources. | map | `{}` | no |
| worker\_additional\_security\_group\_ids | A list of additional security group ids to attach to worker instances | list | `[]` | no |
| worker\_create\_security\_group | Whether to create a security group for the workers or attach the workers to `worker_security_group_id`. | string | `true` | no |
| worker\_group\_count | The number of maps contained within the worker_groups list. | string | `1` | no |
| worker\_group\_launch\_template\_count | The number of maps contained within the worker_groups_launch_template list. | string | `0` | no |
| worker\_groups | A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys. | list | `[ { "name": "default" } ]` | no |
| worker\_groups\_launch\_template | A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys. | list | `[ { "name": "default" } ]` | no |
| worker\_security\_group\_id | If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster. | string | `` | no |
| worker\_sg\_ingress\_from\_port | Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443). | string | `1025` | no |
| workers\_group\_defaults | Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys. | map | `{}` | no |
| workers\_group\_launch\_template\_defaults | Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys. | map | `{}` | no |
| write\_kubeconfig | Whether to write a Kubectl config file containing the cluster configuration. Saved to `config_output_path`. | string | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_arn | The Amazon Resource Name (ARN) of the cluster |
| cluster\_certificate\_authority | Nested attribute containing certificate-authority-data for the cluster |
| cluster\_certificate\_authority\_data | Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster. |
| cluster\_endpoint | endpoint for your Kubernetes API server |
| cluster\_endpoint | The endpoint for your EKS Kubernetes API. |
| cluster\_id | cluster id |
| cluster\_id | The name/id of the EKS cluster. |
| cluster\_platform\_version | platform version for the cluster |
| cluster\_security\_group\_id | Security group ID attached to the EKS cluster. |
| cluster\_security\_group\_id | Security group ID attached to the EKS cluster. |
| cluster\_version | Kubernetes server version for the cluster |
| cluster\_version | The Kubernetes server version for the EKS cluster. |
| cluster\_vpc\_config | Additional nested attributes |
| config\_map\_aws\_auth | A kubernetes configuration to authenticate to this EKS cluster. |
| kubeconfig | kubectl config file contents for this EKS cluster. |
| worker\_iam\_role\_arn | default IAM role ARN for EKS worker groups |
| worker\_iam\_role\_name | default IAM role name for EKS worker groups |
| worker\_security\_group\_id | Security group ID attached to the EKS workers. |
| worker\_security\_group\_id | Security group ID attached to the EKS workers. |
| workers\_asg\_arns | IDs of the autoscaling groups containing workers. |
| workers\_asg\_names | Names of the autoscaling groups containing workers. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
inspired by https://github.com/terraform-aws-modules/terraform-aws-eks