"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createApp = createApp;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const path_1 = __importDefault(require("path"));
const crypto_1 = require("crypto");
const config_1 = require("./config");
const validation_1 = require("./validation");
const preset_1 = __importDefault(require("./routes/preset"));
const notice_1 = __importDefault(require("./routes/notice"));
const sponsor_1 = __importDefault(require("./routes/sponsor"));
const release_1 = __importDefault(require("./routes/release"));
const core_1 = __importDefault(require("./routes/core"));
const health_1 = __importDefault(require("./routes/health"));
function createApp() {
    const app = (0, express_1.default)();
    app.use((0, cors_1.default)());
    app.use(express_1.default.json({ limit: '1mb' }));
    app.use('/data', express_1.default.static(config_1.config.dataDir));
    app.use('/api', (req, res, next) => {
        if (['GET', 'HEAD', 'OPTIONS'].includes(req.method))
            return next();
        const secret = process.env.ADMIN_TOKEN;
        if (!secret) {
            res.status(503).json({ success: false, message: '管理员写入功能未配置' });
            return;
        }
        const digest = (s) => (0, crypto_1.createHash)('sha256').update(s).digest();
        const supplied = req.get('Authorization')?.replace(/^Bearer /, '') ?? '';
        if (!(0, crypto_1.timingSafeEqual)(digest(supplied), digest(secret))) {
            res.status(401).json({ success: false, message: '管理密钥无效' });
            return;
        }
        const parts = req.path.split('/').filter(Boolean);
        const error = parts[0] === 'core' && parts.length === 2
            ? (0, validation_1.validateCorePlatform)(req.body) : (0, validation_1.validateDocument)(parts[0], req.body);
        if (error) {
            res.status(400).json({ success: false, message: error });
            return;
        }
        next();
    });
    app.use('/api/preset', preset_1.default);
    app.use('/api/notices', notice_1.default);
    app.use('/api/sponsors', sponsor_1.default);
    app.use('/api/releases', release_1.default);
    app.use('/api/core', core_1.default);
    app.use('/api/health', health_1.default);
    app.use('/api', (_req, res) => res.status(404).json({ message: 'API 不存在' }));
    app.use(express_1.default.static(path_1.default.join(__dirname, '../public')));
    app.get('*', (_req, res) => res.sendFile(path_1.default.join(__dirname, '../public/index.html')));
    app.use((error, _req, res, _next) => {
        const status = error && typeof error === 'object' && 'status' in error ? Number(error.status) : 500;
        console.error(error);
        res.status(status >= 400 && status < 600 ? status : 500).json({ success: false, message: '请求处理失败' });
    });
    return app;
}
//# sourceMappingURL=app.js.map