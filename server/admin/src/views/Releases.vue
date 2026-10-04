<template>
  <div class="releases-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>版本更新管理</span>
          <el-button type="primary" @click="handleEdit">编辑版本信息</el-button>
        </div>
      </template>
      <el-tabs>
        <el-tab-pane label="应用">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="版本">{{ releaseData.app?.version }}</el-descriptions-item>
            <el-descriptions-item label="构建号">{{ releaseData.app?.buildNumber }}</el-descriptions-item>
            <el-descriptions-item label="更新日志"><pre>{{ releaseData.app?.changelog }}</pre></el-descriptions-item>
          </el-descriptions>
          <el-table :data="appRows" stripe>
            <el-table-column prop="platform" label="平台" width="160" />
            <el-table-column prop="url" label="下载地址" show-overflow-tooltip />
            <el-table-column prop="hash" label="SHA256" show-overflow-tooltip />
          </el-table>
        </el-tab-pane>
        <el-tab-pane v-for="group in coreGroups" :key="group.key" :label="group.label">
          <el-table :data="rows(releaseData[group.key])" stripe>
            <el-table-column prop="platform" label="平台" width="160" />
            <el-table-column prop="version" label="版本" width="120" />
            <el-table-column prop="url" label="下载地址" show-overflow-tooltip />
            <el-table-column prop="hash" label="SHA256" show-overflow-tooltip />
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>
    <el-dialog v-model="dialogVisible" title="编辑版本信息" width="min(800px, 95vw)">
      <el-alert type="info" :closable="false" title="下载地址须使用 HTTPS，SHA256 须为 64 位十六进制；未发布的平台留空。" />
      <el-form v-if="form.app" :model="form" label-width="120px">
        <el-divider>应用</el-divider>
        <el-form-item label="版本"><el-input v-model="form.app.version" /></el-form-item>
        <el-form-item label="构建号"><el-input-number v-model="form.app.buildNumber" :min="1" /></el-form-item>
        <el-form-item label="更新日志"><el-input v-model="form.app.changelog" type="textarea" :rows="3" /></el-form-item>
        <el-collapse>
          <el-collapse-item v-for="platform in platforms" :key="platform" :title="platform" :name="platform">
            <el-form-item label="下载地址"><el-input v-model="form.app.url[platform]" /></el-form-item>
            <el-form-item label="SHA256"><el-input v-model="form.app.hash[platform]" /></el-form-item>
          </el-collapse-item>
        </el-collapse>
        <template v-for="group in coreGroups" :key="group.key">
          <el-divider>{{ group.label }}</el-divider>
          <el-collapse>
            <el-collapse-item v-for="platform in desktopPlatforms" :key="platform" :title="platform" :name="platform">
              <el-form-item label="版本"><el-input v-model="form[group.key][platform].version" /></el-form-item>
              <el-form-item label="下载地址"><el-input v-model="form[group.key][platform].url" /></el-form-item>
              <el-form-item label="SHA256"><el-input v-model="form[group.key][platform].hash" /></el-form-item>
              <el-form-item label="文件名"><el-input v-model="form[group.key][platform].filename" /></el-form-item>
            </el-collapse-item>
          </el-collapse>
        </template>
      </el-form>
      <el-alert v-if="saveError" type="error" :closable="false" :title="saveError" />
      <template #footer>
        <el-button @click="dialogVisible = false" :disabled="saving">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import axios from 'axios'
import { releaseApi } from '@/api'

const desktopPlatforms = ['windows', 'linux', 'macos', 'windows-x64', 'linux-x64', 'linux-arm64', 'macos-x64', 'macos-arm64']
const platforms = [...desktopPlatforms, 'android', 'ohos', 'ios']
const coreGroups = [{ key: 'core', label: 'OpenP2P 核心' }, { key: 'easytier', label: 'EasyTier' }]
const releaseData = ref<any>({})
const form = ref<any>({})
const dialogVisible = ref(false)
const saving = ref(false)
const saveError = ref('')
const rows = (data: Record<string, any> = {}) => Object.entries(data).map(([platform, value]) => ({ platform, ...value }))
const appRows = computed(() => Object.entries(releaseData.value.app?.url || {}).map(([platform, url]) =>
  ({ platform, url, hash: releaseData.value.app?.hash?.[platform] || '' })))

async function loadData() {
  try { releaseData.value = (await releaseApi.get()).data }
  catch { ElMessage.error('加载版本信息失败') }
}
function handleEdit() {
  const value = JSON.parse(JSON.stringify(releaseData.value))
  value.app ||= { version: '', buildNumber: 1, changelog: '' }
  value.app.url ||= {}
  value.app.hash ||= {}
  for (const group of coreGroups) {
    value[group.key] ||= {}
    for (const platform of desktopPlatforms) {
      value[group.key][platform] ||= { version: '', url: '', hash: '', filename: '' }
    }
  }
  form.value = value
  saveError.value = ''
  dialogVisible.value = true
}
async function handleSave() {
  saving.value = true
  saveError.value = ''
  try {
    const value = JSON.parse(JSON.stringify(form.value))
    for (const group of coreGroups) {
      for (const [platform, info] of Object.entries(value[group.key]) as [string, any][]) {
        if (!info.url && !info.version && !info.hash) delete value[group.key][platform]
      }
    }
    await releaseApi.save(value)
    releaseData.value = value
    dialogVisible.value = false
    ElMessage.success('保存成功')
  } catch (error) {
    saveError.value = axios.isAxiosError(error)
      ? error.response?.data?.message || '保存失败，请检查管理密钥和服务器连接。'
      : '版本信息格式无效。'
  } finally { saving.value = false }
}
onMounted(loadData)
</script>

<style scoped>
.card-header { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
pre { white-space: pre-wrap; margin: 0; font: inherit; }
.el-alert { margin-bottom: 16px; }
</style>
