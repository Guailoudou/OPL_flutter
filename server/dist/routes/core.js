"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = require("../db");
const validation_1 = require("../validation");
const db = new db_1.JsonDB('releases.json');
const router = (0, express_1.Router)();
const groups = ['core', 'easytier'];
router.get('/', (_req, res) => {
    const data = db.read();
    res.json({ core: data.core ?? {}, easytier: data.easytier ?? {} });
});
router.get('/:platform', (req, res) => {
    const platform = req.params.platform.toLowerCase();
    if (!validation_1.releasePlatforms.has(platform)) {
        res.status(400).json({ success: false, message: '无效的平台' });
        return;
    }
    const data = db.read();
    res.json({ platform, core: data.core?.[platform], easytier: data.easytier?.[platform] });
});
// Authentication and complete document validation run before these handlers.
router.post('/', (req, res, next) => {
    try {
        const data = db.read();
        for (const group of groups) {
            if (req.body[group] !== undefined)
                data[group] = { ...data[group], ...req.body[group] };
        }
        db.write(data);
        res.json({ success: true, message: '核心信息已更新' });
    }
    catch (error) {
        next(error);
    }
});
router.post('/:platform', (req, res, next) => {
    const platform = req.params.platform.toLowerCase();
    if (!validation_1.releasePlatforms.has(platform)) {
        res.status(400).json({ success: false, message: '无效的平台' });
        return;
    }
    try {
        const data = db.read();
        for (const group of groups) {
            if (req.body[group] !== undefined)
                data[group] = { ...data[group], [platform]: req.body[group] };
        }
        db.write(data);
        res.json({ success: true, message: '核心信息已更新' });
    }
    catch (error) {
        next(error);
    }
});
exports.default = router;
//# sourceMappingURL=core.js.map