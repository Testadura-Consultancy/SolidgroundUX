# Installing SolidGroundUX

## Download

Download the latest SolidGroundUX release bundle from:

https://github.com/Testadura-Mark/SolidGroundUX/releases

The release bundle is provided as:

* `SolidGroundUX-<version>-release.zip`

Copy the release bundle to the target machine and extract it into the SolidGroundUX releases directory:

```bash
sudo mkdir -p /var/lib/solidgroundux/releases

sudo unzip SolidGroundUX-<version>-release.zip \
    -d /var/lib/solidgroundux/releases
```

After extraction, the releases directory should contain files similar to:

* `SolidGroundUX-<version>.tar.gz`
* `SolidGroundUX-<version>.manifest`
* `SolidGroundUX-<version>.tar.gz.sha256`
* `SolidGroundUX-<version>.manifest.sha256`

## Verify (Optional)

Verify the downloaded release files:

```bash
cd /var/lib/solidgroundux/releases

sha256sum -c SolidGroundUX-<version>.tar.gz.sha256
sha256sum -c SolidGroundUX-<version>.manifest.sha256
```

## First-time Installation

For a first-time installation, extract the release archive directly into the root filesystem:

```bash
sudo tar -xzpf \
    /var/lib/solidgroundux/releases/SolidGroundUX-<version>.tar.gz \
    -C /
```

The release archive contains a prepared filesystem layout and will install the
SolidGroundUX commands, libraries, templates, documentation, and deployment
tools into their expected locations.

## Updating

Download the newer SolidGroundUX release bundle and copy it to the target machine.

Extract the release bundle into the SolidGroundUX releases directory and start the installer:

```bash
sudo mkdir -p /var/lib/solidgroundux/releases

sudo unzip SolidGroundUX-<version>-release.zip \
    -d /var/lib/solidgroundux/releases

sudo sgnd-install --product SolidGroundUX
```
The installer selects the newest available SolidGroundUX release package from
/var/lib/solidgroundux/releases, verifies the release files, creates backups,
extracts the package, and updates the installation records.

## Documentation

Framework documentation is available online:

https://testadura-consultancy.github.io/SolidGroundUX/

## Uninstalling

To remove an installed version:

```bash
sgnd-uninstall
```

The uninstall process uses installation metadata recorded during installation.

## Version Archives

SolidGroundUX maintains versioned release artifacts to support repeatable deployments and version rollback scenarios.

See the deployment documentation for details.
