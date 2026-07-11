<template>
  <div class="releases-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>版本更新管理</span>
          <el-button type="primary" @click="handleEdit">
            <el-icon><Edit /></el-icon>
            编辑版本信息
          </el-button>
        </div>
      </template>

      <el-tabs v-model="activeTab">
        <el-tab-pane label="应用版本" name="app">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="版本号">{{ releaseData.app?.version }}</el-descriptions-item>
            <el-descriptions-item label="构建号">{{ releaseData.app?.buildNumber }}</el-descriptions-item>
            <el-descriptions-item label="更新日志">
              <pre style="white-space: pre-wrap; margin: 0;">{{ releaseData.app?.changelog }}</pre>
            </el-descriptions-item>
            <el-descriptions-item label="下载地址">
              <div v-for="(url, platform) in releaseData.app?.url" :key="platform">
                <el-tag style="margin-right: 8px;">{{ platform }}</el-tag>
                <a :href="url" target="_blank">{{ url }}</a>
              </div>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="OpenP2P 核心" name="core">
          <el-table :data="coreTableData" border stripe>
            <el-table-column prop="platform" label="平台" width="120" />
            <el-table-column prop="version" label="版本" width="120" />
            <el-table-column prop="filename" label="文件名" />
            <el-table-column prop="url" label="下载地址" show-overflow-tooltip>
              <template #default="{ row }">
                <a :href="row.url" target="_blank">{{ row.url }}</a>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <el-tab-pane label="EasyTier 核心" name="easytier">
          <el-table :data="easytierTableData" border stripe>
            <el-table-column prop="platform" label="平台" width="120" />
            <el-table-column prop="version" label="版本" width="120" />
            <el-table-column prop="url" label="下载地址" show-overflow-tooltip>
              <template #default="{ row }">
                <a :href="row.url" target="_blank">{{ row.url }}</a>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-dialog v-model="dialogVisible" title="编辑版本信息" width="800px">
      <el-form :model="form" label-width="120px">
        <el-divider content-position="left">应用版本</el-divider>
        <el-form-item label="版本号">
          <el-input v-model="form.app.version" />
        </el-form-item>
        <el-form-item label="构建号">
          <el-input-number v-model="form.app.buildNumber" :min="1" />
        </el-form-item>
        <el-form-item label="更新日志">
          <el-input v-model="form.app.changelog" type="textarea" :rows="4" />
        </el-form-item>
        <el-form-item label="Windows 下载地址">
          <el-input v-model="form.app.url.windows" />
        </el-form-item>
        <el-form-item label="Linux 下载地址">
          <el-input v-model="form.app.url.linux" />
        </el-form-item>
        <el-form-item label="macOS 下载地址">
          <el-input v-model="form.app.url.macos" />
        </el-form-item>

        <el-divider content-position="left">OpenP2P 核心</el-divider>
        <el-form-item label="版本号">
          <el-input v-model="form.core.version" />
        </el-form-item>
        <el-form-item label="Windows 文件名">
          <el-input v-model="form.core.windows.filename" />
        </el-form-item>
        <el-form-item label="Windows 下载地址">
          <el-input v-model="form.core.windows.url" />
        </el-form-item>
        <el-form-item label="Linux 文件名">
          <el-input v-model="form.core.linux.filename" />
        </el-form-item>
        <el-form-item label="Linux 下载地址">
          <el-input v-model="form.core.linux.url" />
        </el-form-item>
        <el-form-item label="macOS 文件名">
          <el-input v-model="form.core.macos.filename" />
        </el-form-item>
        <el-form-item label="macOS 下载地址">
          <el-input v-model="form.core.macos.url" />
        </el-form-item>

        <el-divider content-position="left">EasyTier 核心</el-divider>
        <el-form-item label="版本号">
          <el-input v-model="form.easytier.version" />
        </el-form-item>
        <el-form-item label="Windows 下载地址">
          <el-input v-model="form.easytier.windows.url" />
        </el-form-item>
        <el-form-item label="Linux 下载地址">
          <el-input v-model="form.easytier.linux.url" />
        </el-form-item>
        <el-form-item label="macOS 下载地址">
          <el-input v-model="form.easytier.macos.url" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { releaseApi } from '@/api'

const activeTab = ref('app')
const dialogVisible = ref(false)
const releaseData = ref<any>({})
const form = ref<any>({
  app: {
    version: '',
    buildNumber: 1,
    changelog: '',
    url: { windows: '', linux: '', macos: '' },
    hash: { windows: '', linux: '', macos: '' }
  },
  core: {
    version: '',
    windows: { filename: '', url: '', hash: '' },
    linux: { filename: '', url: '', hash: '' },
    macos: { filename: '', url: '', hash: '' }
  },
  easytier: {
    version: '',
    windows: { url: '', hash: '' },
    linux: { url: '', hash: '' },
    macos: { url: '', hash: '' }
  }
})

const coreTableData = computed(() => {
  const core = releaseData.value.core || {}
  return [
    { platform: 'Windows', ...core.windows },
    { platform: 'Linux', ...core.linux },
    { platform: 'macOS', ...core.macos }
  ]
})

const easytierTableData = computed(() => {
  const easytier = releaseData.value.easytier || {}
  return [
    { platform: 'Windows', ...easytier.windows },
    { platform: 'Linux', ...easytier.linux },
    { platform: 'macOS', ...easytier.macos }
  ]
})

const loadData = async () => {
  try {
    const res = await releaseApi.get()
    releaseData.value = res.data
  } catch (error) {
    ElMessage.error('加载数据失败')
  }
}

const handleEdit = () => {
  form.value = JSON.parse(JSON.stringify(releaseData.value))
  dialogVisible.value = true
}

const handleSave = async () => {
  try {
    await releaseApi.save(form.value)
    releaseData.value = JSON.parse(JSON.stringify(form.value))
    dialogVisible.value = false
    ElMessage.success('保存成功')
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(loadData)
</script>

<style scoped>
.releases-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

pre {
  font-family: inherit;
  font-size: 14px;
}
</style>
