"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.releasePlatforms = void 0;
exports.validateDocument = validateDocument;
exports.validateCorePlatform = validateCorePlatform;
const object = (v) => !!v && typeof v === 'object' && !Array.isArray(v);
const text = (v) => typeof v === 'string';
const port = (v) => Number.isInteger(v) && Number(v) >= 1 && Number(v) <= 65535;
exports.releasePlatforms = new Set(['windows', 'linux', 'macos', 'android', 'ohos', 'ios',
    'windows-x64', 'windows-arm64', 'linux-x64', 'linux-arm64', 'macos-x64', 'macos-arm64']);
function release(v) {
    if (!object(v) || !text(v.version) || !text(v.url) || !text(v.hash))
        return false;
    if (!/^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/.test(String(v.version)))
        return false;
    try {
        const url = new URL(String(v.url));
        if (url.protocol !== 'https:')
            return false;
    }
    catch {
        return false;
    }
    return /^[a-fA-F0-9]{64}$/.test(String(v.hash));
}
function releaseMap(v) {
    return object(v) && Object.entries(v).every(([key, info]) => exports.releasePlatforms.has(key) && release(info));
}
function validateDocument(kind, data) {
    if (!object(data))
        return 'JSON 根节点必须是对象';
    if (kind === 'preset') {
        if (!Array.isArray(data.presets) || !data.presets.every(p => object(p) && text(p.name) &&
            text(p.note) && Array.isArray(p.tunnel) && p.tunnel.every(t => object(t) &&
            port(t.Sport) && port(t.Cport) && ['tcp', 'udp'].includes(String(t.type))))) {
            return '预设必须包含 name、note 和有效的 tunnel 端口/协议';
        }
    }
    else if (kind === 'notices') {
        if (!Array.isArray(data.notices) || !data.notices.every(n => object(n) &&
            text(n.title) && text(n.content) && text(n.time) && Number.isFinite(Date.parse(String(n.time))))) {
            return '公告必须包含 title、content 和有效的 time';
        }
    }
    else if (kind === 'sponsors') {
        if (!Array.isArray(data.sponsors) || !data.sponsors.every(s => object(s) &&
            text(s.name) && typeof s.amount === 'number' && Number.isFinite(s.amount) && s.amount >= 0 &&
            text(s.time) && text(s.message)))
            return '赞助数据格式无效';
    }
    else if (kind === 'releases') {
        if (!object(data.app) || !text(data.app.version) || !text(data.app.changelog) ||
            !Number.isInteger(data.app.buildNumber) || Number(data.app.buildNumber) < 0 ||
            !object(data.app.url) || !object(data.app.hash) ||
            !Object.entries(data.app.url).every(([key, url]) => exports.releasePlatforms.has(key) &&
                (url === '' || release({ version: data.app && data.app.version,
                    url, hash: data.app.hash && data.app.hash[key] }))) ||
            !releaseMap(data.core) || !releaseMap(data.easytier))
            return '版本数据需要有效版本号、HTTPS 下载地址和 SHA256';
    }
    else if (kind === 'core') {
        if (data.core === undefined && data.easytier === undefined)
            return '缺少 core 或 easytier';
        for (const v of [data.core, data.easytier]) {
            if (v !== undefined && !releaseMap(v))
                return '核心数据需要有效版本号、HTTPS 下载地址和 SHA256';
        }
    }
    else
        return '未知的数据类型';
    return null;
}
function validateCorePlatform(data) {
    if (!object(data) || (data.core === undefined && data.easytier === undefined) ||
        [data.core, data.easytier].some(v => v !== undefined && !release(v))) {
        return '核心数据需要有效版本号、HTTPS 下载地址和 SHA256';
    }
    return null;
}
//# sourceMappingURL=validation.js.map