const fs = require('fs');
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '../..');
const mobileNodeModules = path.resolve(projectRoot, 'node_modules');
const workspaceNodeModules = path.resolve(workspaceRoot, 'node_modules');

const watchFolders = [workspaceNodeModules];
const sharedPackages = path.resolve(workspaceRoot, 'packages');
if (fs.existsSync(sharedPackages)) watchFolders.push(sharedPackages);

const config = {
  projectRoot,
  watchFolders,
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [mobileNodeModules, workspaceNodeModules],
    // React must be a singleton. Admin Web intentionally owns its own React
    // version in the workspace, so mobile resolution is pinned explicitly.
    extraNodeModules: {
      react: path.resolve(mobileNodeModules, 'react'),
      'react-native': path.resolve(mobileNodeModules, 'react-native'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(projectRoot), config);
