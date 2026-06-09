# Installing SolidGroundUX

## Download

Download the latest release from:

https://github.com/Testadura-Mark/SolidGroundUX/releases

A release consists of:

* `SolidGroundUX-<version>.tar.gz`
* `SolidGroundUX-<version>.manifest`

Optional verification files:

* `SHA256SUMS`
* `*.sha256`

## Verify (Optional)

Verify the downloaded files:

```bash
sha256sum -c SHA256SUMS
```

## Install

Run the installer using the downloaded archive and manifest:

```bash
sgnd-install \
    --package SolidGroundUX-1.5.2615900.tar.gz \
    --manifest SolidGroundUX-1.5.2615900.manifest
```

or follow the installation instructions provided by the installer.

## Documentation

Framework documentation is available online:

https://testadura-consultancy.github.io/SolidGroundUX/

## Updating

Download a newer release and run:

```bash
sgnd-install \
    --package <new-package>.tar.gz \
    --manifest <new-manifest>.manifest
```

The installer detects an existing installation and performs an upgrade.

## Uninstalling

To remove an installed version:

```bash
sgnd-uninstall
```

The uninstall process uses installation metadata recorded during installation.

## Version Archives

SolidGroundUX maintains versioned release artifacts to support repeatable deployments and version rollback scenarios.

See the deployment documentation for details.
