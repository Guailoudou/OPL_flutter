"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.JsonDB = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const config_1 = require("./config");
class JsonDB {
    constructor(filename) {
        this.filePath = path_1.default.join(config_1.config.dataDir, filename);
        this.ensureFile();
    }
    ensureFile() {
        if (!fs_1.default.existsSync(config_1.config.dataDir)) {
            fs_1.default.mkdirSync(config_1.config.dataDir, { recursive: true });
        }
        if (!fs_1.default.existsSync(this.filePath)) {
            fs_1.default.writeFileSync(this.filePath, '{}', 'utf-8');
        }
    }
    read() {
        const content = fs_1.default.readFileSync(this.filePath, 'utf-8');
        return JSON.parse(content);
    }
    write(data) {
        const temporary = `${this.filePath}.tmp`;
        try {
            fs_1.default.writeFileSync(temporary, JSON.stringify(data, null, 2), { encoding: 'utf-8', flag: 'w' });
            const fd = fs_1.default.openSync(temporary, 'r+');
            try {
                fs_1.default.fsyncSync(fd);
            }
            finally {
                fs_1.default.closeSync(fd);
            }
            fs_1.default.renameSync(temporary, this.filePath);
        }
        finally {
            if (fs_1.default.existsSync(temporary))
                fs_1.default.unlinkSync(temporary);
        }
    }
}
exports.JsonDB = JsonDB;
//# sourceMappingURL=db.js.map