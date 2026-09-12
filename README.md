# v2node
A V2board node backend based on a modified version of xray-core.

**Note: This project requires the [modified version of V2board](https://github.com/wyx2685/v2board)**

## Installation

### One-command installation

```
wget -N https://raw.githubusercontent.com/phungvanquy/v2node-new/main/script/install.sh && bash install.sh
```

The installer downloads compiled binaries from this repository's latest published
release. Run it as root and provide your panel API URL, node ID, and API key when
prompted. To install a specific release, run `bash install.sh v1.0.0` after
downloading the script.

Each release archive includes `config.json`, `geoip.dat`, and `geosite.dat`.
If you skip automatic configuration, edit `/etc/v2node/config.json` with your
panel details, then run `v2node restart`.

## Publishing a release

Push a version tag on the commit you want to release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Use a new version number for each release. The Build and Release workflow builds
the archives and publishes the release after every build succeeds. Wait for the
workflow to finish before installing that version. Pushes to `main` and manual
workflow runs build artifacts without publishing a release.

## Build
``` bash
GOEXPERIMENT=jsonv2 go build -v -o build_assets/v2node -trimpath -ldflags "-X 'github.com/wyx2685/v2node/cmd.version=$version' -s -w -buildid="
```

## Star history

[![Stargazers over time](https://starchart.cc/wyx2685/v2node.svg?variant=adaptive)](https://starchart.cc/wyx2685/v2node)
