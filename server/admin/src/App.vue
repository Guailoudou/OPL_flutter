<template>
  <el-container class="app-container">
    <el-aside width="200px" class="app-aside">
      <div class="logo">OPL 管理后台</div>
      <el-menu
        :default-active="activeMenu"
        router
        class="app-menu"
      >
        <el-menu-item index="/">
          <el-icon><DataLine /></el-icon>
          <span>仪表盘</span>
        </el-menu-item>
        <el-menu-item index="/presets">
          <el-icon><Connection /></el-icon>
          <span>预设隧道</span>
        </el-menu-item>
        <el-menu-item index="/notices">
          <el-icon><Bell /></el-icon>
          <span>公告管理</span>
        </el-menu-item>
        <el-menu-item index="/sponsors">
          <el-icon><User /></el-icon>
          <span>赞助列表</span>
        </el-menu-item>
        <el-menu-item index="/releases">
          <el-icon><Upload /></el-icon>
          <span>版本更新</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="app-header">
        <span>OPL 后端管理系统</span>
        <el-button class="auth-button" @click="configureToken">设置管理密钥</el-button>
      </el-header>
      <el-main class="app-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'

const route = useRoute()
const activeMenu = computed(() => route.path)

async function configureToken() {
  try {
    const { value } = await ElMessageBox.prompt('请输入服务器配置的管理密钥，仅在当前标签页保存。', '管理密钥', {
      inputType: 'password', inputValidator: value => !!value?.trim() || '请输入管理密钥',
      confirmButtonText: '保存', cancelButtonText: '取消'
    })
    sessionStorage.setItem('opl.adminToken', value.trim())
    ElMessage.success('管理密钥已保存')
  } catch { /* Cancel leaves the current credential unchanged. */ }
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
}

.app-container {
  height: 100vh;
}

.app-aside {
  background: #304156;
  color: #fff;
}

.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  font-size: 18px;
  font-weight: bold;
  color: #fff;
  background: #2b3a4a;
}

.app-menu {
  border-right: none;
  background: #304156;
}

.app-menu .el-menu-item {
  color: #bfcbd9;
}

.app-menu .el-menu-item:hover,
.app-menu .el-menu-item.is-active {
  background: #263445;
  color: #409EFF;
}

.app-header {
  background: #fff;
  border-bottom: 1px solid #e6e6e6;
  display: flex;
  align-items: center;
  font-size: 16px;
  font-weight: 500;
}

.app-main {
  background: #f0f2f5;
  padding: 20px;
}

.auth-button { margin-left: auto; }
</style>
