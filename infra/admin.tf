# The control plane: this is where you run ./customer from, plus the
# nightly backup-fleet cron (Infomaniak has no backup scheduler and the laptop
# isn't always awake), plus the stable IP customer SSH rules trust.
#
# It holds the whole platform — OpenStack credential, GCP key, Mailgun key,
# and read/write on tofu state (every customer's HMAC and SMTP secret sits in
# there in plaintext). That is the deliberate trade for provisioning from
# anywhere; it is why there is NO ingress at all and the tailnet is the only
# way in. If tailscaled ever fails to come up, add an ssh rule here and apply
# from the laptop — secgroup rules are a provider-side API call, so an
# unreachable box is never a lockout.
#
# Not a customer box: no Caddy/Authelia/factory, nothing listening.

resource "openstack_networking_secgroup_v2" "admin" {
  name                 = "appsmoothly-admin"
  delete_default_rules = true
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
    tailscale_auth_key = var.tailscale_auth_key
  })

  # This box runs the applies. Without this, an apply from the box can destroy
  # (or replace, which is destroy-first) the box mid-apply. Changing user_data
  # will now error instead — rebuild it deliberately, from the laptop.
  lifecycle {
    prevent_destroy = true
  }
}

output "admin_ip" {
  description = "The stable admin IP — SSH jump host and backup-cron home."
  value       = openstack_compute_instance_v2.admin.access_ip_v4
}
