<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card>
          <div class="stat-card">
            <div class="stat-icon" style="background: #409EFF">
              <el-icon :size="32"><Connection /></el-icon>
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ stats.presets }}</div>
              <div class="stat-label">预设隧道</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div class="stat-card">
            <div class="stat-icon" style="background: #67C23A">
              <el-icon :size="32"><Bell /></el-icon>
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ stats.notices }}</div>
              <div class="stat-label">公告数量</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div class="stat-card">
            <div class="stat-icon" style="background: #E6A23C">
              <el-icon :size="32"><User /></el-icon>
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ stats.sponsors }}</div>
              <div class="stat-label">赞助人数</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div class="stat-card">
            <div class="stat-icon" style="background: #F56C6C">
              <el-icon :size="32"><Upload /></el-icon>
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ stats.appVersion }}</div>
              <div class="stat-label">应用版本</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>核心版本</span>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="Windows">
              <el-tag>{{ coreVersions.windows }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="Linux">
              <el-tag>{{ coreVersions.linux }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="macOS">
              <el-tag>{{ coreVersions.macos }}</el-tag>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>EasyTier 版本</span>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="Windows">
              <el-tag>{{ easytierVersions.windows }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="Linux">
              <el-tag>{{ easytierVersions.linux }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="macOS">
              <el-tag>{{ easytierVersions.macos }}</el-tag>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { presetApi, noticeApi, sponsorApi, releaseApi, coreApi } from '@/api'

const stats = ref({
  presets: 0,
  notices: 0,
  sponsors: 0,
  appVersion: '-'
})

const coreVersions = ref({
  windows: '-',
  linux: '-',
  macos: '-'
})

const easytierVersions = ref({
  windows: '-',
  linux: '-',
  macos: '-'
})

onMounted(async () => {
  try {
    const [presetRes, noticeRes, sponsorRes, releaseRes, coreRes] = await Promise.all([
      presetApi.list(),
      noticeApi.list(),
      sponsorApi.list(),
      releaseApi.get(),
      coreApi.get()
    ])

    stats.value.presets = presetRes.data.presets?.length || 0
    stats.value.notices = noticeRes.data.notices?.length || 0
    stats.value.sponsors = sponsorRes.data.sponsors?.length || 0
    stats.value.appVersion = releaseRes.data.app?.version || '-'

    const core = coreRes.data.core
    if (core) {
      coreVersions.value = {
        windows: core.windows?.version || '-',
        linux: core.linux?.version || '-',
        macos: core.macos?.version || '-'
      }
    }

    const easytier = coreRes.data.easytier
    if (easytier) {
      easytierVersions.value = {
        windows: easytier.windows?.version || '-',
        linux: easytier.linux?.version || '-',
        macos: easytier.macos?.version || '-'
      }
    }
  } catch (error) {
    console.error('Failed to load dashboard data:', error)
  }
})
</script>

<style scoped>
.dashboard {
  padding: 20px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
}

.stat-icon {
  width: 64px;
  height: 64px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #303133;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-top: 4px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 500;
}
</style>
