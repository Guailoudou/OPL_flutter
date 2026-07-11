<template>
  <div class="core-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>核心管理</span>
          <el-button type="primary" @click="handleEdit">
            <el-icon><Edit /></el-icon>
            编辑核心信息
          </el-button>
        </div>
      </template>

      <el-tabs v-model="activeTab">
        <el-tab-pane label="Windows" name="windows">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="OpenP2P 版本">{{ coreData.windows?.core?.version }}</el-descriptions-item>
            <el-descriptions-item label="OpenP2P 下载地址">
              <a :href="coreData.windows?.core?.url" target="_blank">{{ coreData.windows?.core?.url }}</a>
            </el-descriptions-item>
            <el-descriptions-item label="EasyTier 版本">{{ coreData.windows?.easytier?.version }}</el-descriptions-item>
            <el-descriptions-item label="EasyTier 下载地址">
              <a :href="coreData.windows?.easytier?.url" target="_blank">{{ coreData.windows?.easytier?.url }}</a>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="Linux" name="linux">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="OpenP2P 版本">{{ coreData.linux?.core?.version }}</el-descriptions-item>
            <el-descriptions-item label="OpenP2P 下载地址">
              <a :href="coreData.linux?.core?.url" target="_blank">{{ coreData.linux?.core?.url }}</a>
            </el-descriptions-item>
            <el-descriptions-item label="EasyTier 版本">{{ coreData.linux?.easytier?.version }}</el-descriptions-item>
            <el-descriptions-item label="EasyTier 下载地址">
              <a :href="coreData.linux?.easytier?.url" target="_blank">{{ coreData.linux?.easytier?.url }}</a>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="macOS" name="macos">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="OpenP2P 版本">{{ coreData.macos?.core?.version }}</el-descriptions-item>
            <el-descriptions-item label="OpenP2P 下载地址">
              <a :href="coreData.macos?.core?.url" target="_blank">{{ coreData.macos?.core?.url }}</a>
            </el-descriptions-item>
            <el-descriptions-item label="EasyTier 版本">{{ coreData.macos?.easytier?.version }}</el-descriptions-item>
            <el-descriptions-item label="EasyTier 下载地址">
              <a :href="coreData.macos?.easytier?.url" target="_blank">{{ coreData.macos?.easytier?.url }}</a>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-dialog v-model="dialogVisible" title="编辑核心信息" width="700px">
      <el-form :model="form" label-width="150px">
        <el-divider content-position="left">Windows</el-divider>
        <el-form-item label="OpenP2P 版本">
          <el-input v-model="form.windows.core.version" />
        </el-form-item>
        <el-form-item label="OpenP2P 下载地址">
          <el-input v-model="form.windows.core.url" />
        </el-form-item>
        <el-form-item label="OpenP2P 文件名">
          <el-input v-model="form.windows.core.filename" />
        </el-form-item>
        <el-form-item label="EasyTier 版本">
          <el-input v-model="form.windows.easytier.version" />
        </el-form-item>
        <el-form-item label="EasyTier 下载地址">
          <el-input v-model="form.windows.easytier.url" />
        </el-form-item>

        <el-divider content-position="left">Linux</el-divider>
        <el-form-item label="OpenP2P 版本">
          <el-input v-model="form.linux.core.version" />
        </el-form-item>
        <el-form-item label="OpenP2P 下载地址">
          <el-input v-model="form.linux.core.url" />
        </el-form-item>
        <el-form-item label="OpenP2P 文件名">
          <el-input v-model="form.linux.core.filename" />
        </el-form-item>
        <el-form-item label="EasyTier 版本">
          <el-input v-model="form.linux.easytier.version" />
        </el-form-item>
        <el-form-item label="EasyTier 下载地址">
          <el-input v-model="form.linux.easytier.url" />
        </el-form-item>

        <el-divider content-position="left">macOS</el-divider>
        <el-form-item label="OpenP2P 版本">
          <el-input v-model="form.macos.core.version" />
        </el-form-item>
        <el-form-item label="OpenP2P 下载地址">
          <el-input v-model="form.macos.core.url" />
        </el-form-item>
        <el-form-item label="OpenP2P 文件名">
          <el-input v-model="form.macos.core.filename" />
        </el-form-item>
        <el-form-item label="EasyTier 版本">
          <el-input v-model="form.macos.easytier.version" />
        </el-form-item>
        <el-form-item label="EasyTier 下载地址">
          <el-input v-model="form.macos.easytier.url" />
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
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { coreApi } from '@/api'

const activeTab = ref('windows')
const dialogVisible = ref(false)
const coreData = ref<any>({})
const form = ref<any>({
  windows: {
    core: { version: '', url: '', hash: '', filename: '' },
    easytier: { version: '', url: '', hash: '' }
  },
  linux: {
    core: { version: '', url: '', hash: '', filename: '' },
    easytier: { version: '', url: '', hash: '' }
  },
  macos: {
    core: { version: '', url: '', hash: '', filename: '' },
    easytier: { version: '', url: '', hash: '' }
  }
})

const loadData = async () => {
  try {
    const res = await coreApi.get()
    coreData.value = res.data
  } catch (error) {
    ElMessage.error('加载数据失败')
  }
}

const handleEdit = () => {
  form.value = JSON.parse(JSON.stringify(coreData.value))
  dialogVisible.value = true
}

const handleSave = async () => {
  try {
    await coreApi.save(form.value)
    coreData.value = JSON.parse(JSON.stringify(form.value))
    dialogVisible.value = false
    ElMessage.success('保存成功')
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(loadData)
</script>

<style scoped>
.core-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
