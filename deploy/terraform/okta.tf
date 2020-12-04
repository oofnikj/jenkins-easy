terraform {
  required_providers {
    okta = {
      source  = "oktadeveloper/okta"
      version = "~> 3.6"
    }
  }
}

provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  api_token = var.okta_api_token
}
provider "local" {}

variable "okta_org_name" {}
variable "first_name" {}
variable "last_name" {}
variable "email" {}
variable "jenkins_url" {
  default = "http://localhost:8080"
}


resource "okta_user" "admin" {
  admin_roles = ["SUPER_ADMIN"]
  first_name  = var.first_name
  last_name   = var.last_name
  email       = var.email
  login       = var.email
  group_memberships = [
    okta_group.jenkins_admins.id,
  ]
}

resource "okta_group" "jenkins_admins" {
  name = "jenkins-admins"
}

resource "okta_app_group_assignment" "jenkins_admins" {
  app_id   = okta_app_oauth.jenkins.id
  group_id = okta_group.jenkins_admins.id
}


resource "okta_group" "jenkins_users" {
  name = "jenkins-users"
}

resource "okta_app_group_assignment" "jenkins_users" {
  app_id   = okta_app_oauth.jenkins.id
  group_id = okta_group.jenkins_users.id
}

resource "okta_app_oauth" "jenkins" {
  label          = "Jenkins"
  type           = "web"
  grant_types    = ["authorization_code"]
  response_types = ["code"]
  redirect_uris  = ["${var.jenkins_url}/securityRealm/finishLogin"]
  login_uri      = "${var.jenkins_url}/securityRealm/finishLogin"
  lifecycle {
    ignore_changes = [groups]
  }
}

resource "local_file" "okta_secrets" {
  filename             = "../secrets/okta-oidc.env"
  directory_permission = "0755"
  file_permission      = "0600"
  sensitive_content    = <<-EOF
    okta-client-id=${okta_app_oauth.jenkins.client_id}
    okta-client-secret=${okta_app_oauth.jenkins.client_secret}
    okta-org-name=${var.okta_org_name}
  EOF
}

data "okta_auth_server" "default" {
  name = "default"
}

resource "okta_auth_server_claim" "groups" {
  auth_server_id    = data.okta_auth_server.default.id
  name              = "groups"
  scopes            = ["groups"]
  value             = ".*"
  value_type        = "GROUPS"
  group_filter_type = "REGEX"
  claim_type        = "IDENTITY"
}