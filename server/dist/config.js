"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const path_1 = __importDefault(require("path"));
exports.config = {
    port: parseInt(process.env.PORT || '3000', 10),
    dataDir: path_1.default.join(__dirname, 'data'),
};
//# sourceMappingURL=config.js.map