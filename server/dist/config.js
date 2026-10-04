"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const path_1 = __importDefault(require("path"));
exports.config = {
    port: parseInt(process.env.PORT || '3000', 10),
    // Keep one source of truth for both tsx development and dist execution.
    dataDir: process.env.OPL_DATA_DIR || path_1.default.resolve(__dirname, '..', 'src', 'data'),
};
//# sourceMappingURL=config.js.map