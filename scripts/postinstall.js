#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

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
  
  if (!platform || !arch) {
    throw new Error(`Unsupported platform: ${os.platform()}-${os.arch()}`);
  }
  
  return `buildctl-${platform}-${arch}`;
}

function findBinaryInPackage(packageName) {
  try {
    const packagePath = path.dirname(require.resolve(`${packageName}/package.json`));
    const packageJson = require(`${packageName}/package.json`);
    
    if (!packageJson.bin) {
      throw new Error(`No binary found in ${packageName}`);
    }
    
    // Get the first (and should be only) binary
    const binRelPath = Object.values(packageJson.bin)[0];
    const binPath = path.join(packagePath, binRelPath);
    
    if (!fs.existsSync(binPath)) {
      throw new Error(`Binary not found at ${binPath}`);
    }
    
    return binPath;
  } catch (error) {
    return null;
  }
}

function createBinaryLink() {
  const binDir = path.join(__dirname, '..', 'bin');
  const binaryPath = path.join(binDir, 'buildctl');
  
  // Create bin directory if it doesn't exist
  if (!fs.existsSync(binDir)) {
    fs.mkdirSync(binDir, { recursive: true });
  }
  
  // Remove existing binary if it exists
  if (fs.existsSync(binaryPath)) {
    fs.unlinkSync(binaryPath);
  }
  
  try {
    const platformPackage = getPlatformPackageName();
    const sourceBinary = findBinaryInPackage(platformPackage);
    
    if (!sourceBinary) {
      console.warn(`Warning: Could not find binary for platform ${platformPackage}`);
      console.warn('This may be because the platform-specific package is not installed.');
      return;
    }
    
    // Copy the binary
    fs.copyFileSync(sourceBinary, binaryPath);
    
    // Make it executable on Unix-like systems
    if (os.platform() !== 'win32') {
      fs.chmodSync(binaryPath, 0o755);
    }
    
    console.log(`buildctl binary installed for ${os.platform()}-${os.arch()}`);
  } catch (error) {
    console.warn(`Warning: Could not install buildctl binary: ${error.message}`);
    console.warn('You may need to install manually or use a platform-specific package.');
  }
}

// Only run if this script is executed directly
if (require.main === module) {
  createBinaryLink();
}

module.exports = { createBinaryLink, getPlatformPackageName };