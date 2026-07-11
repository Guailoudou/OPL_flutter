"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const path_1 = __importDefault(require("path"));
const config_1 = require("./config");
const preset_1 = __importDefault(require("./routes/preset"));
const notice_1 = __importDefault(require("./routes/notice"));
const sponsor_1 = __importDefault(require("./routes/sponsor"));
const release_1 = __importDefault(require("./routes/release"));
const core_1 = __importDefault(require("./routes/core"));
const health_1 = __importDefault(require("./routes/health"));
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
// API路由
app.use('/api/preset', preset_1.default);
app.use('/api/notices', notice_1.default);
app.use('/api/sponsors', sponsor_1.default);
app.use('/api/releases', release_1.default);
app.use('/api/core', core_1.default);
app.use('/api/health', health_1.default);
// 静态文件服务
app.use(express_1.default.static(path_1.default.join(__dirname, '../public')));
// Vue SPA 路由支持 - 所有非 API 请求都返回 index.html
app.get('*', (req, res) => {
    res.sendFile(path_1.default.join(__dirname, '../public/index.html'));
});
app.listen(config_1.config.port, () => {
    console.log(`OPL Server running on http://localhost:${config_1.config.port}`);
    console.log(`Admin panel: http://localhost:${config_1.config.port}/admin`);
});
//# sourceMappingURL=index.js.map