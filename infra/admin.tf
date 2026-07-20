# Always-on admin box: a stable IP the customer SSH rules can trust (your
# home IP changes; this one doesn't) and the nightly backup-fleet cron
# (Infomaniak has no backup scheduler and the laptop isn't always awake).
#
# Deliberately NOT a customer box: no Caddy/Authelia/factory, nothing
# listening but SSH (key-only, open — it's the fallback when your home IP
# changes). It holds exactly one credential: a second OpenStack application
# credential for imaging servers — no GCP, no Mailgun, no tofu state.

resource "openstack_networking_secgroup_v2" "admin" {
  name                 = "appsmoothly-admin"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "admin_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.admin.id
}

resource "openstack_networking_secgroup_rule_v2" "admin_egress_v4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.admin.id
}

resource "openstack_networking_secgroup_rule_v2" "admin_egress_v6" {
  direction         = "egress"
  ethertype         = "IPv6"
  security_group_id = openstack_networking_secgroup_v2.admin.id
}

resource "openstack_compute_instance_v2" "admin" {
  name            = "appsmoothly-admin"
  image_name      = var.image
  flavor_name     = var.admin_flavor
  key_pair        = openstack_compute_keypair_v2.admin.name
  security_groups = [openstack_networking_secgroup_v2.admin.name]

  network {
    name = var.network
  }

  user_data = templatefile("${path.module}/admin-cloud-init.yaml.tftpl", {
    os_auth_url              = var.os_auth_url
    os_region                = var.os_region
    backup_credential_id     = var.backup_credential_id
    backup_credential_secret = var.backup_credential_secret
  })
}

output "admin_ip" {
  description = "The stable admin IP — SSH jump host and backup-cron home."
  value       = openstack_compute_instance_v2.admin.access_ip_v4
}
