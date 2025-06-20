# MEMORIES.md - buildctl-npm Project

> Notes for future agentic sessions working on this project

## Project Overview
This project redistributes the `buildctl` binary from [BuildKit](https://github.com/moby/buildkit) as NPM packages, providing per-architecture packages for cross-platform compatibility.

## Key Architecture Decisions

### Package Structure
- **Main package**: `buildctl` - wrapper package with postinstall script
- **Platform packages**: `buildctl-{os}-{arch}` - contain actual binaries
- **Consistent bin name**: All packages export `"buildctl"` (not platform-specific names)

### Binary Naming Convention
- **Unix/macOS**: `bin/buildctl` (no extension)
- **Windows**: `bin/buildctl.exe` (with .exe extension)
- **NPM bin field**: Always `"buildctl": "bin/{binary}"` for consistency

## Supported Platforms
- **macOS**: darwin-arm64, darwin-x64
- **Linux**: linux-x64, linux-arm64, linux-arm, linux-ppc64, linux-riscv64, linux-s390x
- **Windows**: win32-x64, win32-arm64

## Critical Technical Details

### Windows Binary Extraction Issue
**Problem**: Windows tar.gz files have different structure than Unix:
- Unix: `buildctl` (root level)
- Windows: `bin/buildctl.exe` (in subdirectory)

**Solution**: Updated extraction logic in `scripts/publish.go`:
```go
targetBinary := "buildctl"
if o.String() == "win32" {
    targetBinary = "buildctl.exe"
}
if strings.HasSuffix(header.Name, "/"+targetBinary) || header.Name == targetBinary {
```

### File Paths in Scripts
Scripts run from `scripts/` directory but need to access parent directory:
- `parentP, err := ioutil.ReadFile("../package.json")`
- `npm, err := filepath.Abs("../npm")`

### Go Module Structure
- Go dependencies are in `scripts/go.mod`
- Module name: `github.com/turbokube/buildctl-npm/scripts`
- Required dependencies: `github.com/google/go-github/v50`, `go.uber.org/zap`

## Working Scripts

### scripts/publish.go
Generates all platform-specific packages:
```bash
cd scripts && go run publish.go
```
- Downloads BuildKit releases from GitHub
- Extracts buildctl binaries from tar.gz files
- Creates npm/ directory with platform packages
- Outputs publish commands (but doesn't run them)

### scripts/test.go
Validates generated packages:
```bash
cd scripts && go run test.go
```
- Checks all packages in npm/ directory
- Validates package.json structure
- Tests binary existence and executability
- Calculates SHA256 checksums
- Attempts to get version info from binaries
- Outputs JSON report + summary

### scripts/postinstall.js
Runtime installation script for main package:
- Detects current platform/architecture
- Finds appropriate platform-specific package
- Copies binary to main package bin/ directory
- Handles cross-platform compatibility

## buildctl-dockerfile Implementation

### Overview
Added a Docker-compatible wrapper command `buildctl-dockerfile` (alias `buildctl-d`) that provides familiar `docker build` syntax for common buildctl operations.

### Command Structure
```bash
buildctl-dockerfile [OPTIONS] CONTEXT
```

### Key Implementation Details

#### Argument Parsing Strategy
- Uses Node.js-based argument parser in `bin/buildctl-dockerfile`
- Validates arguments before constructing buildctl command
- Supports short and long option formats (`-f` / `--file`)
- Handles multiple build arguments via repeated `--build-arg` flags

#### buildctl Command Translation
The wrapper translates Docker-style options to buildctl syntax:
```bash
# Docker-style input:
buildctl-dockerfile -f custom.dockerfile --build-arg KEY=VALUE -t image:tag ./context

# Translates to:
buildctl build --frontend dockerfile.v0 \
  --local context=./context \
  --local dockerfile=./context \
  --opt filename=custom.dockerfile \
  --opt build-arg:KEY=VALUE \
  --output type=image,name=image:tag,push=false
```

#### Critical Implementation Points

1. **Dockerfile Validation**: 
   - Validates Dockerfile exists at specified path or default location
   - Handles both absolute and relative paths for custom Dockerfiles
   - Resolves paths relative to current working directory

2. **Context Handling**:
   - Context path is resolved to absolute path
   - Dockerfile directory is extracted separately for `--local dockerfile=`
   - Default Dockerfile location is `{context}/Dockerfile`

3. **Build Arguments**:
   - Format validated as `KEY=VALUE`
   - Prefixed with `build-arg:` in buildctl command
   - Multiple arguments supported

4. **Output Handling**:
   - With tag: `--output type=image,name={tag},push=false`
   - Without tag: `--output type=docker` (default)

#### Error Handling Strategy
- Context path validation (existence check)
- Dockerfile existence validation
- Build argument format validation
- Clear error messages with help display on failure
- Proper exit codes (0 for success, 1 for errors)

#### Testing Strategy
- **Dry-run mode**: `--dry-run` flag shows buildctl command without execution
- **Regression tests**: Documented in `TESTS.md`
- **Error case coverage**: Missing context, missing Dockerfile, invalid arguments

### Files Modified/Created
- `bin/buildctl-dockerfile`: Main implementation
- `package.json`: Already had bin entries for `buildctl-dockerfile` and `buildctl-d`
- `README.md`: Added documentation with examples
- `TESTS.md`: Comprehensive test suite for regression testing

### Common Usage Patterns
```bash
# Basic usage
buildctl-dockerfile .

# With build args
buildctl-dockerfile --build-arg NODE_VERSION=18 .

# Custom Dockerfile
buildctl-dockerfile -f prod.dockerfile .

# With tagging
buildctl-dockerfile -t myapp:v1.0 .

# Dry run (testing)
buildctl-dockerfile --dry-run .
```

### Platform Compatibility
- Works on all supported platforms (uses Node.js)
- Resolves correct buildctl binary path using existing PLATFORMS mapping
- Handles Windows `.exe` extension automatically

### Future Enhancements Considered
- Could add support for more Docker build options (--target, --cache-from, etc.)
- Could add support for build contexts via URL/Git
- Could add support for multi-platform builds
- Currently focused on core Docker build compatibility

### Debugging Notes
- Use `--dry-run` to see exact buildctl command being generated
- Check `TESTS.md` for comprehensive test cases
- Argument parsing happens before buildctl validation
- Error messages designed to be user-friendly while maintaining technical accuracy

## Version Management
- Version is hardcoded in `scripts/publish.go`: `publishVersion = "0.22.0"`
- All generated packages use this version
- BuildKit regex: `^buildkit-v(?P<version>\d+\.\d+\.\d+)\.(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9\-]+)\.tar\.gz$`

## Testing Workflow
1. **Generate packages**: `cd scripts && go run publish.go`
2. **Validate packages**: `cd scripts && go run test.go`
3. **Check structure**: Verify npm/ directory contains all 10 platform packages
4. **Test binaries**: Should all be executable with correct checksums

## Publishing Workflow
Scripts output NPM publish commands but don't execute them:
```bash
(cd npm/buildctl-darwin-x64; npm publish --access public)
(cd npm/buildctl-darwin-arm64; npm publish --access public)
# ... for all platform packages
npm publish --access public  # Main package
```

## Common Issues & Solutions

### "No binary found" for Windows
- **Cause**: Windows binaries are in `bin/` subdirectory within tar.gz
- **Check**: Extraction logic handles both `/buildctl.exe` and `buildctl.exe`

### Wrong bin names in package.json
- **Solution**: Always use `"buildctl"` as bin name, not platform-specific names
- **Implementation**: `Bin: map[string]string{"buildctl": fmt.Sprintf("bin/%s", exename)}`

### Go module issues
- **Always run from scripts/ directory**: `cd scripts && go run {script}.go`
- **Dependencies**: Managed in `scripts/go.mod`, not root directory

### File permissions
- Binaries must have executable permissions (0755)
- Checked automatically in test script

## File Structure Reference
```
buildctl-npm/
├── package.json          # Main package metadata
├── README.md            # User documentation
├── .gitignore           # Excludes npm/ directory
├── .npmignore           # Excludes scripts/ and development files
├── MEMORIES.md          # This file
├── scripts/
│   ├── go.mod           # Go dependencies
│   ├── go.sum           # Go dependency checksums
│   ├── publish.go       # Package generation
│   ├── test.go          # Package validation
│   └── postinstall.js   # Runtime installation
└── npm/                 # Generated packages (gitignored)
    ├── buildctl-darwin-arm64/
    ├── buildctl-darwin-x64/
    ├── buildctl-linux-*/
    └── buildctl-win32-*/
```

## Important URLs
- **BuildKit releases**: https://github.com/moby/buildkit/releases
- **Release pattern**: `https://github.com/moby/buildkit/releases/download/v{version}/buildkit-v{version}.{os}-{arch}.tar.gz`
- **Main repo**: https://github.com/turbokube/buildctl-npm

## Future Maintenance
- Update `publishVersion` in `scripts/publish.go` for new BuildKit releases
- Test script validates all 10 platforms - any failures need investigation
- Windows packages most likely to have issues due to different archive structure
- Platform package names should match NPM package naming conventions