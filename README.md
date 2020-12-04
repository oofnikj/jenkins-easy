# Easy Jenkins

A 100% declarative approach to deploying Jenkins on Kubernetes, including plugins, jobs definitions, and user authentication.

Read more: [badgateway.qc.to/deploy-jenkins-the-easy-way](https://badgateway.qc.to/deploy-jenkins-the-easy-way)

## Prerequisites:
- a running Kubernetes cluster (any flavor, >= v1.16)

In addition, some local tools are required:
* `kubectl`
* `kustomize`
* `terraform`

For the Okta OpenID Connect configuration, if you don't already have one, sign up for a free Okta developer account. Your org name will look something like `dev-1582052`.

## Configuring Okta
Jenkins user and group management is handled by Okta in this example. Any other OIDC-capable identity provider can work here.

This can be done manually of course, but since we're opting for a 100% declarative approach,
a Terraform script for configuring Okta is included in [`deploy/terraform/okta.tf`](deploy/terraform/okta.tf). 

The script creates a user with the given variables and adds that user to a group called "jenkins-admins". It also configures the default authorization server to include a scope and matching claim called `groups` in the identity token requested by Jenkins to include a list of groups to which the user belongs.

Combined with the Matrix Authorization Jenkins plugin, we can configure fine-grained access controls to specific Jenkins jobs based on IdP group membership.

- Create a file called `terraform.tfvars` in `deploy/terraform/` with your config:
```sh
$ cd deploy/terraform
$ set -a # export all shell variables
$ OKTA_ORG_NAME=<your Okta org>
$ OKTA_BASE_URL=okta.com # most likely value
$ OKTA_API_TOKEN=<...>
$ cat <<EOF > terraform.tfvars
okta_org_name  = "${OKTA_ORG_NAME}"
okta_base_url  = "${OKTA_BASE_URL}"
okta_api_token = "${OKTA_API_TOKEN}"
first_name     = "Zaphod"
last_name      = "Beeblebrox"
email          = "me@example.com"
jenkins_url    = "http://localhost:8080" # for testing
EOF
```
**NOTE:** If you're trying to add a user with the same name with which you signed up for your developer account, Okta will throw an error. Either import your existing user ID with `terraform import okta_user.admin <user_id>` or use a different name.

- Initialize the provider and apply:
```
$ terraform init
$ terraform apply
```

Terraform will generate the file `deploy/secrets/okta-oidc.env` containing your Jenkins OIDC client ID and secret which will be used in the next step.

## Deployment
- Generate a SSH key pair for Jenkins to access your Git repository:
```sh
$ cd deploy/
$ REPO_NAME=jenkins-easy
$ ssh-keygen -t ecdsa -f secrets/${REPO_NAME}.pem
```
Add the resultant public key, `secrets/${REPO_NAME}.pem.pub`, to your Git provider as a deploy key. Check "Allow write access" if you have jobs that need to write to Git, e.g. for tagging commits with build numbers.



### Kustomize

**NOTE:** As of December 2020 the `kustomize` sub-command built in to `kubectl` is incompatible with the v3 manifest in this repository. Don't use `kubectl kustomize`! Instead, install `kustomize` 3.x with your favorite package manager.

* Deploy the FluxCD Helm Operator:
```sh
$ kustomize build helm-operator | kubectl apply -f-
```

* Deploy the Jenkins Helm chart, config and secrets:
```sh
$ kustomize build . | kubectl apply -f-
```

After a few moments, you should be able to log in to your Jenkins instance at http://localhost:8080 by port-forwarding:
```sh
$ kubectl port-forward -n jenkins svc/jenkins 8080
```

Run the seed job, which will check out your repository and load all of your job definitions. By default these are expected to be in `jobs/**/job.dsl`.

## Maintenance

Jenkins configuration should only be modified through the Helm values in order to be persistent.

After making changes, re-run the final deploy step:
```sh
$ kustomize build . | kubectl apply -f-
```

After a few moments, the FluxCD Helm Operator will pick up on the changes redeploy the Helm chart.

## References
* https://github.com/jenkinsci/job-dsl-plugin/wiki
* https://github.com/jenkinsci/configuration-as-code-plugin
* https://gerg.dev/2020/06/creating-a-job-dsl-seed-job-with-jcasc/
* https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-kustomize/
* https://developer.okta.com/blog/2019/10/21/illustrated-guide-to-oauth-and-oidc
* https://www.terraform.io/docs/providers/okta/index.html