import fs from 'fs';
import path from 'path'
import { injectNativeModules } from 'flutter-hvigor-plugin';

const flutterProjectPath = path.dirname(__dirname);
const pluginsMetadataPath = path.join(flutterProjectPath, '.flutter-plugins-dependencies');

if (fs.existsSync(pluginsMetadataPath)) {
  const metadata = JSON.parse(fs.readFileSync(pluginsMetadataPath, 'utf8'));
  if (!metadata.plugins || typeof metadata.plugins !== 'object') {
    metadata.plugins = {};
  }
  if (!Array.isArray(metadata.plugins.ohos)) {
    metadata.plugins.ohos = [];
    fs.writeFileSync(pluginsMetadataPath, JSON.stringify(metadata));
  }
  injectNativeModules(__dirname, flutterProjectPath);
}
