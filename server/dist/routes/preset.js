"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = require("../db");
const db = new db_1.JsonDB('preset.json');
const router = (0, express_1.Router)();
router.get('/', (req, res) => {
    const data = db.read();
    res.json(data);
});
router.post('/', (req, res) => {
    try {
        const newData = req.body;
        db.write(newData);
        res.json({ success: true, message: '预设数据已保存' });
    }
    catch (error) {
        res.status(500).json({ success: false, message: '保存失败: ' + error });
    }
});
exports.default = router;
//# sourceMappingURL=preset.js.map