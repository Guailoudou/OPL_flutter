"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = require("../db");
const db = new db_1.JsonDB('releases.json');
const router = (0, express_1.Router)();
// GET /api/core - 获取所有平台核心信息
router.get('/', (req, res) => {
    const data = db.read();
    res.json({
        core: data.core,
        easytier: data.easytier
    });
});
// GET /api/core/:platform - 获取指定平台核心信息
router.get('/:platform', (req, res) => {
    const platform = req.params.platform.toLowerCase();
    const validPlatforms = ['windows', 'linux', 'macos'];
    if (!validPlatforms.includes(platform)) {
        return res.status(400).json({
            success: false,
            message: '无效的平台，支持: windows, linux, macos'
        });
    }
    const data = db.read();
    const coreInfo = data.core[platform];
    const easytierInfo = data.easytier[platform];
    res.json({
        platform,
        core: coreInfo,
        easytier: easytierInfo
    });
});
// POST /api/core - 更新核心信息
router.post('/', (req, res) => {
    try {
        const { core, easytier } = req.body;
        const data = db.read();
        if (core) {
            // 验证并更新 core 数据
            for (const platform of ['windows', 'linux', 'macos']) {
                if (core[platform]) {
                    const platformData = core[platform];
                    if (!platformData.version || !platformData.url || !platformData.hash) {
                        return res.status(400).json({
                            success: false,
                            message: `${platform} 平台 core 数据不完整，需要 version, url, hash`
                        });
                    }
                    data.core[platform] = platformData;
                }
            }
        }
        if (easytier) {
            // 验证并更新 easytier 数据
            for (const platform of ['windows', 'linux', 'macos']) {
                if (easytier[platform]) {
                    const platformData = easytier[platform];
                    if (!platformData.version || !platformData.url || !platformData.hash) {
                        return res.status(400).json({
                            success: false,
                            message: `${platform} 平台 easytier 数据不完整，需要 version, url, hash`
                        });
                    }
                    data.easytier[platform] = platformData;
                }
            }
        }
        db.write(data);
        res.json({ success: true, message: '核心信息已更新' });
    }
    catch (error) {
        res.status(500).json({ success: false, message: '更新失败: ' + error });
    }
});
// POST /api/core/:platform - 更新指定平台核心信息
router.post('/:platform', (req, res) => {
    const platform = req.params.platform.toLowerCase();
    const validPlatforms = ['windows', 'linux', 'macos'];
    if (!validPlatforms.includes(platform)) {
        return res.status(400).json({
            success: false,
            message: '无效的平台，支持: windows, linux, macos'
        });
    }
    try {
        const { core, easytier } = req.body;
        const data = db.read();
        if (core) {
            if (!core.version || !core.url || !core.hash) {
                return res.status(400).json({
                    success: false,
                    message: 'core 数据不完整，需要 version, url, hash'
                });
            }
            data.core[platform] = core;
        }
        if (easytier) {
            if (!easytier.version || !easytier.url || !easytier.hash) {
                return res.status(400).json({
                    success: false,
                    message: 'easytier 数据不完整，需要 version, url, hash'
                });
            }
            data.easytier[platform] = easytier;
        }
        db.write(data);
        res.json({ success: true, message: `${platform} 平台核心信息已更新` });
    }
    catch (error) {
        res.status(500).json({ success: false, message: '更新失败: ' + error });
    }
});
exports.default = router;
//# sourceMappingURL=core.js.map