# buildctl with `docker build` syntax

You have three types of container image builds:

- Language-specific like [ko](https://ko.build/) and [jib](https://github.com/GoogleContainerTools/jib).
- Add files to a base image. Lots of tools can do that locally as layers are just tarballs. Use for example [contain](https://github.com/turbokube/contain).
- One that needs to run commands in the base image. For that use [buildkit](https://github.com/moby/buildkit/).

In the latter case, buildkit's client CLI [buildctl](https://github.com/moby/buildkit/?tab=readme-ov-file#building-a-dockerfile-with-buildctl) is great because it doesn't depend on any docker-ish platform.

While BuildKit is a generic DAG runner we only ever care about it's ability to process Dockerfiles.

## npm package

This repo publishes the NPM package [buildctl](https://www.npmjs.com/package/buildctl) that redistributes the client binary from [BuildKit releases](https://github.com/moby/buildkit/releases).

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

### buildctl-dockerfile Command

This package also provides a `buildctl-dockerfile` command (aliased as `buildctl-d`) that offers a simplified interface similar to `docker build` for common Dockerfile-based builds:

```bash
buildctl-dockerfile [OPTIONS] CONTEXT
```

**Options:**
- `-f, --file DOCKERFILE` - Path to the Dockerfile (default: `Dockerfile` in context)
- `--build-arg KEY=VALUE` - Set build arguments
- `-t, --tag IMAGE` - Name and optionally tag for the built image
- `--push` - Push the image to registry (requires `-t/--tag` or `--output` in passthrough)
- `--dry-run` - Print the buildctl command that would be executed
- `--` - Pass remaining arguments directly to buildctl

**Examples:**

```bash
# Build with default Dockerfile in current directory
buildctl-dockerfile .

# Build with custom Dockerfile
buildctl-dockerfile -f custom.Dockerfile .

# Build with build arguments
buildctl-dockerfile --build-arg NODE_VERSION=18 --build-arg ENV=production .

# Build and tag the image
buildctl-dockerfile -t myapp:latest .

# Build, tag and push the image
buildctl-dockerfile -t myregistry.com/myapp:latest --push .

# See what buildctl command would be executed (dry run)
buildctl-dockerfile --dry-run .

# Combine options
buildctl-dockerfile -f docker/Dockerfile -t myapp:v1.0 --build-arg VERSION=1.0 ./src

# Pass additional buildctl options
buildctl-dockerfile . -- --progress=plain --no-cache --export-cache type=local,dest=/tmp/cache

# Override output destination (ignores -t flag if specified)
buildctl-dockerfile -t ignored:tag . -- --output type=registry,name=myregistry.com/image:latest,push=true
```

**Note**: If `--output` is provided in passthrough arguments (after `--`), it will override any output configuration from the `-t/--tag` option. The command validates for conflicting options:
- Cannot use both `-t/--tag` and `name=` in passthrough `--output`
- Cannot use both `--push` and `push=` in passthrough `--output`
- `--push` requires either `-t/--tag` or `--output` in passthrough arguments

The command translates these familiar options into the appropriate `buildctl build` syntax with the dockerfile frontend.

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

## Testing

To run the regression test suite for the `buildctl-dockerfile` command:

```bash
./test-dockerfile.sh
```

See `TESTS.md` for detailed test documentation and manual test cases.