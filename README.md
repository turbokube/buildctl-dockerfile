# buildctl

NPM package that redistributes the [buildctl](https://github.com/moby/buildkit) binary from the [BuildKit](https://github.com/moby/buildkit) project.

BuildKit is a toolkit for converting source code to build artifacts in an efficient, expressive and repeatable manner. `buildctl` is its command-line interface.

## Installation

```bash
npm install buildctl
```

Or globally:

```bash
npm install -g buildctl
```

## Usage

After installation, the `buildctl` command will be available:

```bash
buildctl --help
```

## Supported Platforms

This package automatically installs the correct binary for your platform:

- **macOS**: arm64, amd64
- **Linux**: amd64, arm64, arm-v7, ppc64le, riscv64, s390x  
- **Windows**: amd64, arm64

## How it works

This package uses optional dependencies to install platform-specific packages containing the buildctl binary for your system. The main package serves as a wrapper that selects the appropriate binary.

Platform-specific packages follow the naming pattern: `buildctl-{os}-{arch}`

## Versioning

Package versions correspond to BuildKit releases. For example, version `0.22.0` contains buildctl from BuildKit v0.22.0.

## License

This package is licensed under Apache-2.0, same as BuildKit.

The buildctl binary is built and distributed by the BuildKit project: https://github.com/moby/buildkit