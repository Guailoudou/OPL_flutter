"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("./config");
const app_1 = require("./app");
(0, app_1.createApp)().listen(config_1.config.port, () => {
    console.log(`OPL Server listening on port ${config_1.config.port}`);
    if (!process.env.ADMIN_TOKEN)
        console.warn('ADMIN_TOKEN is unset; admin writes are disabled.');
});
//# sourceMappingURL=index.js.map