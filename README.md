# Easy Jenkins

A 100% declarative approach to deploying Jenkins on Kubernetes, including plugins, jobs definitions, and user authentication.

Read more: [badgateway.qc.to/deploy-jenkins-the-easy-way](https://badgateway.qc.to/deploy-jenkins-the-easy-way)

## Prerequisites:
- a running Kubernetes cluster (any flavor, >= v1.19)

In addition, some local tools are required:
* `terraform`
* `kubectl`
* `flux` (v2)

For the Okta OpenID Connect configuration, if you don't already have one, sign up for a free Okta developer account. Your org name will look something like `dev-1582052`.

## Configuring Okta
Jenkins user and group management is handled by Okta in this example. Any other OIDC-capable identity provider can work here.

This can be done manually of course, but since we're opting for a 100% declarative approach,
a Terraform script for configuring Okta is included in [`deploy/terraform/okta.tf`](deploy/terraform/okta.tf). 

The script creates a user with the given variables and adds that user to a group called "jenkins-admins". It also configures the default authorization server to include a scope and matching claim called `groups` in the identity token requested by Jenkins to include a list of groups to which the user belongs.

Combined with the Matrix Authorization Jenkins plugin, we can configure fine-grained access controls to specific Jenkins jobs based on IdP group membership.

- Create an Okta API token in the admin portal under Security > API.

- Create a file called `terraform.tfvars` in `deploy/terraform/` with your config (this file is ignored by Git):
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
**NOTE:** If you're trying to add a user with the same name with which you signed up for your developer account, Okta will throw an error. Either import your existing user ID with `terraform import okta_user.admin <user_id>` or use a different name. Obtain your user ID by visiting the Okta portal and navigating to Directory > People and clicking on the desired user. The user ID is visible in the browser URL as a random string.

- Initialize the provider and apply:
```
$ terraform init
$ terraform apply
```

Terraform will generate the file `deploy/secrets/okta-oidc.yaml` containing your Jenkins OIDC client ID and secret which will be used in the next steps.

## Deployment
- Generate a SSH key pair for Jenkins to access your Git repository:
```sh
$ REPO_NAME=jenkins-easy
$ ssh-keygen -t ecdsa -f deploy/secrets/${REPO_NAME}.pem
```
Add the resulting **public** key, `deploy/secrets/${REPO_NAME}.pem.pub`, to your Git provider as a deploy key. Check "Allow write access" to allow the deploy key to write to Git.

### Secrets management
We're using Mozilla `sops` to encrypt and store secrets in Git. Follow the [Flux docs](https://fluxcd.io/docs/guides/mozilla-sops/) on setting up encryption for your cluster using either `gpg`, `age`, or a cloud-based KMS solution. This example uses the `gpg` workflow outlined in the linked documentation.

- Convert the Okta secrets and SSH deploy key generated in the previous step to SOPS-encrypted Kubernetes secrets:
```sh
$ cd $(git rev-parse --show-toplevel)
$ kubectl kustomize deploy/secrets -o deploy/secrets/jenkins-easy.pem.yaml
$ sops --config=clusters/kube-1/.sops.yaml --encrypt \
  deploy/secrets/jenkins-easy.pem.yaml > deploy/kube-1/jenkins-easy.pem.enc.yaml
$ sops --config=clusters/kube-1/.sops.yaml --encrypt \
  deploy/secrets/okta-oidc.yaml > deploy/kube-1/okta-oidc.enc.yaml
```

The generated files ending in `.enc.yaml` can be safely committed to Git as long as the private PGP key is kept secure or, if you are using cloud KMS, access to the KMS key is restricted using appropriate IAM controls.
### Flux

Install Flux v2 using the Flux toolkit CLI. This will bootstrap Flux in the currently selected Kubernetes context, configure it to sync with your Git repository and push the configuration back up to Git. This is the only step that needs direct access to your Kubernetes cluster.

The configuration in `clusters/kube-1` is included here as an example. Choosing another path (e.g. `clusters/penny-farthing-6`) will result in the creation of that directory and the placement of configuration files pertaining to that cluster in it.

```sh
$ flux bootstrap git --url=ssh://git@github.com/oofnikj/jenkins-easy \
  --private-key-file=secrets/jenkins-easy.pem \
  --path=clusters/kube-1 \
  --silent
```

After a few moments, you should be able to log in to your Jenkins instance at http://localhost:8080 by port-forwarding:
```sh
$ kubectl port-forward -n jenkins svc/jenkins 8080
```

Run the seed job, which will check out your repository and load all of your job definitions. The configuration here looks for Jenkins jobs in `jobs/**/job.dsl`. Note that you may need to approve the seed script if running for the first time under "Manage Jenkins > In-Process Script Approval".

## Maintenance

Jenkins configuration, including plugin installation and upgrades, should only be modified through the Helm values in order to be persistent. GitOps means that all configuration changes should happen through version control. Any `kubectl edit`s will be eventually overridden by Flux according to the contents of your cluster repository at the specified branch.

## References
* https://github.com/jenkinsci/job-dsl-plugin/wiki
* https://github.com/jenkinsci/configuration-as-code-plugin
* https://gerg.dev/2020/06/creating-a-job-dsl-seed-job-with-jcasc/
* https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-kustomize/
* https://developer.okta.com/blog/2019/10/21/illustrated-guide-to-oauth-and-oidc
* https://www.terraform.io/docs/providers/okta/index.html
* https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/examples/