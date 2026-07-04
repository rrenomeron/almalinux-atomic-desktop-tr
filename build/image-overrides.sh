#!/usr/bin/bash

set -eoux pipefail

# Use this for build steps that are unique to this particular image

dnf install -y adwaita-mono-fonts \
    just 
# Apparently this needs to be done for non-RHEL EL in order to download images from Red Hat.
# See https://access.redhat.com/articles/3116561

# Since Apr 20 2026 we can't do this during build time.

cat << SCRIPT > /usr/sbin/set-redhat-registry-trust
#!/usr/bin/bash
set -eoux pipefail
podman image trust set -f /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release registry.access.redhat.com
podman image trust set -f /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release registry.redhat.io
SCRIPT
chmod ugo+x /usr/sbin/set-redhat-registry-trust

cat << SYSTEMD_UNIT > /usr/lib/systemd/system/trust-redhat-registry.service
[Unit]
Description=Set Trust for Red Hat Container Registries
Documentation=https://access.redhat.com/articles/3116561

[Service]
Type=oneshot
ExecStart=/usr/sbin/set-redhat-registry-trust

[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT

systemctl enable trust-redhat-registry.service

cat << EOF > /etc/containers/registries.d/registry.access.redhat.com.yaml
docker:
     registry.access.redhat.com:
         sigstore: https://access.redhat.com/webassets/docker/content/sigstore
EOF
cat << EOF > /etc/containers/registries.d/registry.redhat.io.yaml
docker:
     registry.redhat.io:
         sigstore: https://registry.redhat.io/containers/sigstore
EOF

echo "Adding Intel One Mono Font"
/tmp/scripts/run_module.sh 'fonts' \
  '{ "type": "fonts", "fonts" : {"url-fonts": [ { "name": "intel-one-mono", "url": "https://github.com/intel/intel-one-mono/releases/download/V1.4.0/otf.zip" } ] }}'