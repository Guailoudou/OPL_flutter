#!/usr/bin/env node

/**
 * 自动化版本发布脚本
 *
 * 用法:
 *   node release.js app <version> <changelog>   — 构建并发布 App
 *   node release.js core <version>              — 发布 Core（需先放置构建产物）
 *   node release.js easytier <version>          — 发布 EasyTier（需先放置构建产物）
 *   node release.js all <version>               — 发布全部组件
 *
 * 环境变量 (或 .env 文件):
 *   SFTP_HOST     — SFTP 主机地址
 *   SFTP_PORT     — SFTP 端口 (默认 22)
 *   SFTP_USER     — SFTP 用户名
 *   SFTP_KEY      — SSH 私钥路径 (可选，优先于密码)
 *   SFTP_PASS     — SFTP 密码
 *   SFTP_REMOTE   — 远程上传目录 (默认 /file/releases)
 *   RELEASES_URL  — 文件下载基础 URL (默认 https://file.gldhn.top/file/releases)
 *   FLUTTER_ROOT  — Flutter SDK 路径 (默认 flutter)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

// ─── 依赖检查 ────────────────────────────────────────────────────────────────

let Client;
try {
  Client = require('ssh2-sftp-client');
} catch {
  console.error('缺少依赖，请先运行: npm install ssh2-sftp-client');
  process.exit(1);
}

// ─── 配置 ────────────────────────────────────────────────────────────────────

const ROOT = path.resolve(__dirname, '..', '..');
const SERVER_DIR = path.resolve(__dirname, '..');
const RELEASES_JSON = path.join(SERVER_DIR, 'src', 'data', 'releases.json');
const BUILD_DIR = path.join(ROOT, 'build');
const STAGING_DIR = path.join(SERVER_DIR, 'scripts', '.staging');

function loadEnv() {
  const envPath = path.join(SERVER_DIR, 'scripts', '.env');
  if (fs.existsSync(envPath)) {
    fs.readFileSync(envPath, 'utf-8').split('\n').forEach((line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      const eq = trimmed.indexOf('=');
      if (eq === -1) return;
      const key = trimmed.slice(0, eq).trim();
      const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
      if (!process.env[key]) process.env[key] = val;
    });
  }
}
loadEnv();

const CONFIG = {
  sftp: {
    host: process.env.SFTP_HOST || '',
    port: parseInt(process.env.SFTP_PORT || '22', 10),
    username: process.env.SFTP_USER || '',
    privateKey: process.env.SFTP_KEY ? fs.readFileSync(process.env.SFTP_KEY) : undefined,
    password: process.env.SFTP_PASS || '',
    remoteDir: process.env.SFTP_REMOTE || '/file/releases',
  },
  releasesUrl: process.env.RELEASES_URL || 'https://file.gldhn.top/file/releases',
  flutter: process.env.FLUTTER_ROOT || 'flutter',
};

const PLATFORM = process.platform; // win32 | linux | darwin

const PLATFORM_FILES = {
  app: {
    win32: { ext: '.exe', remoteName: (v) => `opl-${v}.exe` },
    linux: { ext: '', remoteName: (v) => `opl-${v}.tar.gz` },
    darwin: { ext: '.dmg', remoteName: (v) => `opl-${v}.dmg` },
  },
};

// ─── 工具函数 ────────────────────────────────────────────────────────────────

function log(msg) {
  console.log(`\x1b[36m[release]\x1b[0m ${msg}`);
}

function logOk(msg) {
  console.log(`\x1b[32m  ✓\x1b[0m ${msg}`);
}

function logErr(msg) {
  console.error(`\x1b[31m  ✗\x1b[0m ${msg}`);
}

function sha256(filePath) {
  const hash = crypto.createHash('sha256');
  const stream = fs.createReadStream(filePath);
  return new Promise((resolve, reject) => {
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function readReleases() {
  return JSON.parse(fs.readFileSync(RELEASES_JSON, 'utf-8'));
}

function writeReleases(data) {
  fs.writeFileSync(RELEASES_JSON, JSON.stringify(data, null, 2) + '\n');
}

function bumpBuildNumber(releases) {
  releases.app.buildNumber = (releases.app.buildNumber || 0) + 1;
}

function run(cmd, cwd) {
  log(`执行: ${cmd}`);
  execSync(cmd, { cwd, stdio: 'inherit' });
}

// ─── SFTP 上传 ───────────────────────────────────────────────────────────────

async function uploadFile(localPath, remoteName) {
  if (!CONFIG.sftp.host) {
    log('未配置 SFTP_HOST，跳过上传。请手动上传文件。');
    return;
  }

  const sftp = new Client();
  const remotePath = `${CONFIG.sftp.remoteDir}/${remoteName}`;

  try {
    log(`连接 SFTP: ${CONFIG.sftp.host}:${CONFIG.sftp.port}`);
    await sftp.connect(CONFIG.sftp);

    log(`上传: ${path.basename(localPath)} → ${remotePath}`);
    await sftp.put(localPath, remotePath);
    logOk(`上传完成: ${remoteName}`);
  } finally {
    await sftp.end();
  }
}

// ─── App 发布 ────────────────────────────────────────────────────────────────

async function releaseApp(version, changelog) {
  log(`开始发布 App v${version}...`);

  // 1. 更新 pubspec.yaml 版本号
  const pubspecPath = path.join(ROOT, 'pubspec.yaml');
  let pubspec = fs.readFileSync(pubspecPath, 'utf-8');
  const releases = readReleases();
  const buildNumber = (releases.app.buildNumber || 0) + 1;
  pubspec = pubspec.replace(/^version:.*$/m, `version: ${version}+${buildNumber}`);
  fs.writeFileSync(pubspecPath, pubspec);
  logOk(`pubspec.yaml → version: ${version}+${buildNumber}`);

  // 2. 构建
  log('构建 Flutter 应用...');
  if (PLATFORM === 'win32') {
    run(`${CONFIG.flutter} build windows --release`, ROOT);
  } else if (PLATFORM === 'darwin') {
    run(`${CONFIG.flutter} build macos --release`, ROOT);
  } else {
    log('当前平台不支持自动构建 App，请手动构建后将产物放入 staging 目录。');
  }

  // 3. 打包构建产物
  ensureDir(STAGING_DIR);
  let buildArtifact;

  if (PLATFORM === 'win32') {
    const exeName = `opl-${version}.exe`;
    const sourceDir = path.join(BUILD_DIR, 'windows', 'x64', 'runner', 'Release');
    // 使用 7z 或 tar 打包
    const archivePath = path.join(STAGING_DIR, exeName);
    // 直接复制 runner 目录下的 exe（如有 NSIS 安装包则用安装包）
    const builtExe = path.join(sourceDir, 'opl_config_manager.exe');
    if (fs.existsSync(builtExe)) {
      fs.copyFileSync(builtExe, archivePath);
      buildArtifact = archivePath;
    } else {
      logErr(`未找到构建产物: ${builtExe}`);
      process.exit(1);
    }
  } else {
    logErr('非 Windows 平台请手动构建并放置产物到 scripts/.staging/');
    process.exit(1);
  }

  // 4. 计算 hash
  const hash = await sha256(buildArtifact);
  logOk(`SHA256: ${hash}`);

  // 5. 上传
  const remoteName = PLATFORM_FILES.app[PLATFORM].remoteName(version);
  await uploadFile(buildArtifact, remoteName);

  // 6. 更新 releases.json
  const platformKey = PLATFORM === 'win32' ? 'windows' : PLATFORM === 'darwin' ? 'macos' : 'linux';
  releases.app.version = version;
  releases.app.buildNumber = buildNumber;
  releases.app.changelog = changelog || releases.app.changelog;
  releases.app.url[platformKey] = `${CONFIG.releasesUrl}/${remoteName}`;
  releases.app.hash[platformKey] = hash;
  writeReleases(releases);
  logOk(`releases.json 已更新 (app v${version})`);

  log(`App v${version} 发布完成!`);
}

// ─── Core 发布 ───────────────────────────────────────────────────────────────

async function releaseCore(version) {
  log(`开始发布 Core v${version}...`);

  const releases = readReleases();
  const platforms = ['windows', 'linux', 'macos'];
  const archMap = { windows: 'amd64', linux: 'amd64', macos: 'amd64' };

  ensureDir(STAGING_DIR);

  for (const platform of platforms) {
    const filename = `openp2p-${platform}-${archMap[platform]}.tar.gz`;
    const localPath = path.join(STAGING_DIR, filename);

    if (!fs.existsSync(localPath)) {
      logErr(`未找到 Core 构建产物: ${localPath}`);
      log(`请将 ${filename} 放入 ${STAGING_DIR} 后重新运行`);
      continue;
    }

    const hash = await sha256(localPath);
    logOk(`${platform} SHA256: ${hash}`);

    const remoteName = filename;
    await uploadFile(localPath, remoteName);

    releases.core[platform] = {
      version,
      url: `${CONFIG.releasesUrl}/${remoteName}`,
      hash,
      filename,
    };
  }

  writeReleases(releases);
  logOk(`releases.json 已更新 (core v${version})`);
  log(`Core v${version} 发布完成!`);
}

// ─── EasyTier 发布 ───────────────────────────────────────────────────────────

async function releaseEasytier(version) {
  log(`开始发布 EasyTier v${version}...`);

  const releases = readReleases();
  const platforms = ['windows', 'linux', 'macos'];
  const fileMap = {
    windows: `easytier-windows-x86_64-v${version}.zip`,
    linux: `easytier-linux-x86_64-v${version}.zip`,
    macos: `easytier-macos-v${version}.zip`,
  };

  ensureDir(STAGING_DIR);

  for (const platform of platforms) {
    const filename = fileMap[platform];
    const localPath = path.join(STAGING_DIR, filename);

    if (!fs.existsSync(localPath)) {
      logErr(`未找到 EasyTier 构建产物: ${localPath}`);
      log(`请将 ${filename} 放入 ${STAGING_DIR} 后重新运行`);
      continue;
    }

    const hash = await sha256(localPath);
    logOk(`${platform} SHA256: ${hash}`);

    await uploadFile(localPath, filename);

    releases.easytier[platform] = {
      version,
      url: `${CONFIG.releasesUrl}/${filename}`,
      hash,
    };
  }

  writeReleases(releases);
  logOk(`releases.json 已更新 (easytier v${version})`);
  log(`EasyTier v${version} 发布完成!`);
}

// ─── 主入口 ──────────────────────────────────────────────────────────────────

async function main() {
  const [component, version, ...rest] = process.argv.slice(2);

  if (!component || !version) {
    console.log(`
自动化版本发布脚本

用法:
  node release.js app <version> [changelog]   构建并发布 App
  node release.js core <version>              发布 Core (需先放置构建产物)
  node release.js easytier <version>          发布 EasyTier (需先放置构建产物)
  node release.js all <version>               发布全部组件

环境变量 (或 scripts/.env 文件):
  SFTP_HOST     SFTP 主机地址
  SFTP_PORT     SFTP 端口 (默认 22)
  SFTP_USER     SFTP 用户名
  SFTP_KEY      SSH 私钥路径 (可选)
  SFTP_PASS     SFTP 密码
  SFTP_REMOTE   远程上传目录 (默认 /file/releases)
  RELEASES_URL  文件下载基础 URL

示例:
  node release.js app 0.2.0 "新增XX功能\\n修复XX问题"
  node release.js core 1.3.0
  node release.js easytier 2.7.0
`);
    process.exit(0);
  }

  if (!CONFIG.sftp.host) {
    log('警告: 未配置 SFTP_HOST，将跳过文件上传。');
    log('请在 server/scripts/.env 中配置 SFTP 连接信息。');
  }

  try {
    switch (component) {
      case 'app':
        await releaseApp(version, rest.join(' '));
        break;
      case 'core':
        await releaseCore(version);
        break;
      case 'easytier':
        await releaseEasytier(version);
        break;
      case 'all':
        await releaseApp(version, rest.join(' '));
        await releaseCore(version);
        await releaseEasytier(version);
        break;
      default:
        logErr(`未知组件: ${component}`);
        process.exit(1);
    }
  } catch (err) {
    logErr(`发布失败: ${err.message}`);
    process.exit(1);
  }
}

main();
