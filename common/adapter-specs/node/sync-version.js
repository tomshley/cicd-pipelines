#!/usr/bin/env node

/**
 * Canonical reference implementation for CI/CD version composition in Node.js.
 * 
 * This script reads a VERSION file and composes the version with a CI build revision
 * identifier, then updates package.json with the result.
 * 
 * Contract:
 * - Walk up directory tree from current working directory to find VERSION file
 * - Read TOMSHLEY_CICD_BUILD_REVISION from environment
 * - Normalize suffixes for npm compatibility (-SNAPSHOT → -0)
 * - Compose version with hyphen separator if revision is non-empty
 * - Update package.json version field
 * 
 * @see https://gitlab.com/tomshley/tomshley-oss-dependencies/-/tree/main/cicd-pipelines/common/adapter-specs/
 */

const fs = require('fs');
const path = require('path');

/**
 * Find VERSION file by walking up directory tree.
 * @param {string} startDir - Directory to start searching from
 * @returns {string|null} Path to VERSION file, or null if not found
 */
function findVersionFile(startDir = process.cwd()) {
  let currentDir = path.resolve(startDir);
  
  while (currentDir !== path.dirname(currentDir)) {
    const versionPath = path.join(currentDir, 'VERSION');
    if (fs.existsSync(versionPath)) {
      return versionPath;
    }
    currentDir = path.dirname(currentDir);
  }
  
  // Check root directory one last time
  const versionPath = path.join(currentDir, 'VERSION');
  if (fs.existsSync(versionPath)) {
    return versionPath;
  }
  
  return null;
}

/**
 * Normalize version suffix for npm compatibility.
 * @param {string} version - Raw version string
 * @returns {string} Normalized version string
 */
function normalizeVersion(version) {
  // Convert -SNAPSHOT to -0 for npm compatibility
  return version.replace(/-SNAPSHOT$/, '-0');
}

/**
 * Compose version with revision identifier.
 * @param {string} baseVersion - Base version from VERSION file
 * @param {string} revision - Revision from TOMSHLEY_CICD_BUILD_REVISION
 * @returns {string} Composed version
 */
function composeVersion(baseVersion, revision) {
  const normalizedBase = normalizeVersion(baseVersion.trim());
  
  if (!revision || revision.trim() === '') {
    return normalizedBase;
  }
  
  return `${normalizedBase}-${revision.trim()}`;
}

/**
 * Update package.json version field.
 * @param {string} newVersion - New version to set
 * @param {string} packageJsonPath - Path to package.json (defaults to ./package.json)
 */
function updatePackageJson(newVersion, packageJsonPath = './package.json') {
  if (!fs.existsSync(packageJsonPath)) {
    console.error(`Error: ${packageJsonPath} not found`);
    process.exit(1);
  }
  
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  const oldVersion = packageJson.version;
  
  packageJson.version = newVersion;
  fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
  
  console.log(`Updated version: ${oldVersion} → ${newVersion}`);
}

/**
 * Main execution.
 */
function main() {
  const versionFile = findVersionFile();
  
  if (!versionFile) {
    console.error('Error: VERSION file not found');
    process.exit(1);
  }
  
  const baseVersion = fs.readFileSync(versionFile, 'utf8').trim();
  const revision = process.env.TOMSHLEY_CICD_BUILD_REVISION || '';
  
  const composedVersion = composeVersion(baseVersion, revision);
  
  // Get package.json path from command line args, or default to ./package.json
  const packageJsonPath = process.argv[2] || './package.json';
  
  updatePackageJson(composedVersion, packageJsonPath);
}

// Export functions for testing
module.exports = {
  findVersionFile,
  normalizeVersion,
  composeVersion,
  updatePackageJson
};

// Run main function if called directly
if (require.main === module) {
  main();
}
