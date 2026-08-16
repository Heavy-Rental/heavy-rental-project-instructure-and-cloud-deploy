# Documented exception: NAT is a lone aws_instance, not an ASG.
# Do not replace this with aws_nat_gateway.

resource "aws_instance" "nat" {
  ami                         = local.ami_id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  source_dest_check           = false
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  vpc_security_group_ids      = [aws_security_group.nat.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    echo 'net.ipv4.ip_forward = 1' >/etc/sysctl.d/99-ip-forward.conf
    sysctl -w net.ipv4.ip_forward=1
    IFACE="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"
    if command -v nft >/dev/null 2>&1; then
      nft add table ip nat 2>/dev/null || true
      nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority 100 ; }' 2>/dev/null || true
      nft add rule ip nat POSTROUTING oifname "$${IFACE}" masquerade 2>/dev/null || true
    fi
    dnf install -y iptables || true
    iptables -t nat -C POSTROUTING -o "$${IFACE}" -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o "$${IFACE}" -j MASQUERADE
    iptables -C FORWARD -j ACCEPT 2>/dev/null || iptables -A FORWARD -j ACCEPT
  EOF

  tags = {
    Name = "nat-academy"
    Role = "nat"
  }

  lifecycle {
    create_before_destroy = true
  }
}
