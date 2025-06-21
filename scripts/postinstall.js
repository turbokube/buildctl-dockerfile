#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

// Helper function for consistent logging
function log(message) {
  console.log(`[buildctl-postinstall] ${message}`);
}

function logError(message) {
  console.error(`[buildctl-postinstall] ERROR: ${message}`);
}

function logWarning(message) {
  console.warn(`[buildctl-postinstall] WARNING: ${message}`);
}

// Map Node.js platform names to our package names
const platformMap = {
  'darwin': 'darwin',
  'linux': 'linux',
  'win32': 'win32'
};

// Map Node.js arch names to our package names
const archMap = {
  'x64': 'x64',
  'arm64': 'arm64',
  'arm': 'arm',
  'ppc64': 'ppc64',
  'riscv64': 'riscv64',
  's390x': 's390x'
};

function getPlatformPackageName() {
  const platform = platformMap[os.platform()];
  const arch = archMap[os.arch()];

  log(`Detecting platform: ${os.platform()} -> ${platform || 'UNSUPPORTED'}`);
  log(`Detecting architecture: ${os.arch()} -> ${arch || 'UNSUPPORTED'}`);

  if (!platform || !arch) {
    const errorMsg = `Unsupported platform: ${os.platform()}-${os.arch()}`;
    logError(errorMsg);
    throw new Error(errorMsg);
  }

  const packageName = `buildctl-${platform}-${arch}`;
  log(`Target package name: ${packageName}`);
  return packageName;
}

function findBinaryInPackage(packageName) {
  log(`Looking for binary in package: ${packageName}`);

  try {
    // Try to resolve package.json
    const packageJsonPath = `${packageName}/package.json`;
    log(`Attempting to resolve: ${packageJsonPath}`);

    const resolvedPath = require.resolve(packageJsonPath);
    log(`Package.json resolved to: ${resolvedPath}`);

    const packagePath = path.dirname(resolvedPath);
    log(`Package directory: ${packagePath}`);

    const packageJson = require(packageJsonPath);
    log(`Package.json loaded successfully`);
    log(`Package version: ${packageJson.version || 'unknown'}`);
    log(`Package bin field: ${JSON.stringify(packageJson.bin)}`);

    if (!packageJson.bin) {
      const errorMsg = `No binary found in ${packageName}`;
      logError(errorMsg);
      throw new Error(errorMsg);
    }

    // Get the first (and should be only) binary
    const binRelPath = Object.values(packageJson.bin)[0];
    log(`Binary relative path: ${binRelPath}`);

    const binPath = path.join(packagePath, binRelPath);
    log(`Full binary path: ${binPath}`);

    if (!fs.existsSync(binPath)) {
      const errorMsg = `Binary not found at ${binPath}`;
      logError(errorMsg);
      throw new Error(errorMsg);
    }

    const stats = fs.statSync(binPath);
    log(`Binary found! Size: ${stats.size} bytes, executable: ${!!(stats.mode & parseInt('111', 8))}`);

    return binPath;
  } catch (error) {
    logError(`Failed to find binary in package ${packageName}: ${error.message}`);
    return null;
  }
}

function createBinaryLink() {
  log('Starting postinstall process...');
  log(`Current working directory: ${process.cwd()}`);
  log(`Script location: ${__dirname}`);

  const binDir = path.join(__dirname, '..', 'bin');
  const binaryPath = path.join(binDir, 'buildctl');

  log(`Target bin directory: ${binDir}`);
  log(`Target binary path: ${binaryPath}`);

  // Create bin directory if it doesn't exist
  if (!fs.existsSync(binDir)) {
    log('Creating bin directory...');
    fs.mkdirSync(binDir, { recursive: true });
    log('Bin directory created successfully');
  } else {
    log('Bin directory already exists');
  }

  // Remove existing binary if it exists
  if (fs.existsSync(binaryPath)) {
    log('Removing existing binary...');
    fs.unlinkSync(binaryPath);
    log('Existing binary removed');
  } else {
    log('No existing binary to remove');
  }

  try {
    log('Getting platform-specific package name...');
    const platformPackage = getPlatformPackageName();

    log('Searching for source binary...');
    const sourceBinary = findBinaryInPackage(platformPackage);

    if (!sourceBinary) {
      logWarning(`Could not find binary for platform ${platformPackage}`);
      logWarning('This may be because the platform-specific package is not installed.');
      logWarning('Available packages in node_modules:');

      // List available buildctl packages for debugging
      try {
        const nodeModulesPath = path.join(__dirname, '..', 'node_modules');
        if (fs.existsSync(nodeModulesPath)) {
          const packages = fs.readdirSync(nodeModulesPath)
            .filter(name => name.startsWith('buildctl-'))
            .sort();
          if (packages.length > 0) {
            packages.forEach(pkg => log(`  - ${pkg}`));
          } else {
            log('  - No buildctl-* packages found');
          }
        } else {
          log('  - node_modules directory not found');
        }
      } catch (listError) {
        logWarning(`Could not list packages: ${listError.message}`);
      }

      return;
    }

    log(`Copying binary from ${sourceBinary} to ${binaryPath}...`);
    fs.copyFileSync(sourceBinary, binaryPath);
    log('Binary copied successfully');

    // Make it executable on Unix-like systems
    if (os.platform() !== 'win32') {
      log('Setting executable permissions...');
      fs.chmodSync(binaryPath, 0o755);
      log('Executable permissions set');
    } else {
      log('Skipping permission setting on Windows');
    }

    // Verify the final binary
    const finalStats = fs.statSync(binaryPath);
    log(`Final binary stats: size=${finalStats.size} bytes, mode=${finalStats.mode.toString(8)}`);

    log(`✓ buildctl binary installed successfully for ${os.platform()}-${os.arch()}`);
  } catch (error) {
    logError(`Could not install buildctl binary: ${error.message}`);
    logError(`Stack trace: ${error.stack}`);
    logWarning('You may need to install manually or use a platform-specific package.');
  }
}

// Only run if this script is executed directly
if (require.main === module) {
  log('='.repeat(60));
  log('Starting buildctl postinstall script');
  log(`Node.js version: ${process.version}`);
  log(`Platform: ${process.platform} (${process.arch})`);
  log(`Environment: ${process.env.NODE_ENV || 'not set'}`);
  log('='.repeat(60));

  createBinaryLink();

  log('='.repeat(60));
  log('Postinstall script completed');
  log('='.repeat(60));
}

module.exports = { createBinaryLink, getPlatformPackageName };