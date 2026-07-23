variable "customers" {
  description = "One entry per customer box; the key becomes <key>.<zone>. Managed by ./customer in customers.auto.tfvars.json."
  type = map(object({
    admin_email = string # first Authelia login + Let's Encrypt contact
  }))
  default = {}
}

variable "zone" {
  description = "Parent DNS zone for customer subdomains (a Designate zone here; delegated once from the parent domain)."
  type        = string
  default     = "appsmoothly.com"
}

variable "zone_email" {
  description = "SOA contact for the Designate zone."
  type        = string
  default     = "hostmaster@appsmoothly.com"
}

variable "gcp_project" {
  description = "GCP project that holds the per-customer backup buckets."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH (your IP, e.g. 203.0.113.7/32)."
  type        = string
}

variable "admin_ssh_pubkey" {
  description = "Public key for admin SSH to the boxes."
  type        = string
}

# Verify the three below against your Infomaniak project once:
#   openstack flavor list ; openstack image list ; openstack network list
variable "flavor" {
  type    = string
  default = "a2-ram4-disk40-perf1"
}

variable "image" {
  type    = string
  default = "Ubuntu 24.04 LTS Noble Numbat"
}

variable "network" {
  type    = string
  default = "ext-net1"
}

variable "admin_flavor" {
  description = "Smallest flavor that exists — the admin box only runs a cron. Verify: openstack flavor list"
  type        = string
  default     = "a1-ram2-disk20-perf1"
}

# Tailscale auth key for the admin box. Make it REUSABLE and TAGGED
# (tailscale admin console → Settings → Keys); tagged nodes never expire, so
# the box doesn't drop off the tailnet in 90 days while you aren't looking.
variable "tailscale_auth_key" {
  type      = string
  sensitive = true
}

variable "gcs_location" {
  # europe-west1/west4/north1 are GCS's cheapest European tier ($0.020/GB-mo
  # Standard); europe-west6 (Zurich) is ~25% more for no benefit here.
  type    = string
  default = "europe-west1"
}

variable "factory_repo" {
  description = "The appsmoothly repo cloned onto each box."
  type        = string
  default     = "https://github.com/LukBrezina/appsmoothly.git"
}
