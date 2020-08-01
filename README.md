# Easy Jenkins
### A 100% declarative approach to deploying Jenkins on Kubernetes

Read more: [badgateway.qc.to/deploy-jenkins-the-easy-way](https://badgateway.qc.to/deploy-jenkins-the-easy-way)

## Prerequisites:
A Kubernetes cluster with the FluxCD Helm Operator installed ([instructions](https://docs.fluxcd.io/projects/helm-operator/en/latest/get-started/using-helm/))

In addition, some local tools are required:
* `kubectl`
* `kustomize`
* `helm`
* `terraform`

Finally, for the Okta OpenID Connect configuration, if you don't already have one, sign up for a free Okta developer account.

## Configuring Okta
Jenkins user and group management is handled by Okta in this example. Any other OIDC-capable identity provider can work here.

This can be done manually of course, but since we're opting for a 100% declarative approach,
a Terraform script for configuring Okta is included in [`deploy/terraform/okta.tf`](deploy/terraform/okta.tf). 

The script creates a user with the given variables and adds that user to a group called "jenkins-admins". It also configures the default authorization server to include a claim called `groups` in the identity token requested by Jenkins to include a list of groups to which the user belongs.

Combined with the Matrix Authorization Jenkins plugin, we can configure fine-grained access controls to specific Jenkins jobs based on IdP group membership.

Create a file called `terraform.tfvars` in `deploy/terraform/` with your config and apply:
```sh
$ cd deploy/terraform
$ set -a # export all shell variables
$ OKTA_ORG_NAME=<your Okta org>
$ OKTA_BASE_URL=okta.com # most likely value
$ OKTA_API_TOKEN=<...>
$ cat <<EOF > terraform.tfvars
okta_org_name = ${OKTA_ORG_NAME}
first_name    = <first_name>
last_name     = <last_name>
email         = <email>
jenkins_url   = <your_jenkins_url>
EOF
$ terraform init
$ terraform apply
```

Terraform will generate a file `deploy/secrets/okta-oidc.env` containing your Jenkins OIDC client ID and secret which will be used in the next step.

## Deployment
Generate a SSH key pair for Jenkins to access your Git repository:
```sh
$ cd deploy/
$ REPO_NAME=jenkins-easy
$ ssh-keygen -t ecdsa -f secrets/${REPO_NAME}.pem
```
Add the resultant public key, `secrets/${REPO_NAME}.pem.pub`, to your Git provider as a deploy key.



### Deploy with Kustomize
```sh
kustomize build | kubectl apply -f-
```

After deploying, you should be able to log in to your Jenkins instance by port-forwarding:
```sh
$ kubectl port-forward -n jenkins 


## References
* https://www.terraform.io/docs/providers/okta/index.html
* https://developer.okta.com/blog/2019/10/21/illustrated-guide-to-oauth-and-oidc
* https://gerg.dev/2020/06/creating-a-job-dsl-seed-job-with-jcasc/
* https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-helm/