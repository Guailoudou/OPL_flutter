<template>
  <div class="presets-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>预设隧道管理</span>
          <el-button type="primary" @click="handleAdd">
            <el-icon><Plus /></el-icon>
            添加预设
          </el-button>
        </div>
      </template>

      <el-table :data="presets" border stripe>
        <el-table-column prop="name" label="名称" width="150" />
        <el-table-column prop="note" label="说明" />
        <el-table-column label="隧道配置" width="200">
          <template #default="{ row }">
            <el-tag v-for="(tunnel, idx) in row.tunnel" :key="idx" style="margin-right: 4px">
              {{ tunnel.type.toUpperCase() }}: {{ tunnel.Sport }} → {{ tunnel.Cport }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ $index }">
            <el-button type="primary" size="small" @click="handleEdit($index)">编辑</el-button>
            <el-button type="danger" size="small" @click="handleDelete($index)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑预设' : '添加预设'" width="600px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="名称">
          <el-input v-model="form.name" placeholder="例如：饥荒联机版" />
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="form.note" type="textarea" :rows="3" placeholder="使用说明" />
        </el-form-item>
        <el-form-item label="隧道配置">
          <div v-for="(tunnel, index) in form.tunnel" :key="index" style="margin-bottom: 10px">
            <el-row :gutter="10">
              <el-col :span="6">
                <el-select v-model="tunnel.type" placeholder="协议">
                  <el-option label="TCP" value="tcp" />
                  <el-option label="UDP" value="udp" />
                </el-select>
              </el-col>
              <el-col :span="8">
                <el-input-number v-model="tunnel.Sport" placeholder="源端口" :min="1" :max="65535" />
              </el-col>
              <el-col :span="8">
                <el-input-number v-model="tunnel.Cport" placeholder="目标端口" :min="1" :max="65535" />
              </el-col>
              <el-col :span="2">
                <el-button type="danger" size="small" @click="removeTunnel(index)">
                  <el-icon><Delete /></el-icon>
                </el-button>
              </el-col>
            </el-row>
          </div>
          <el-button type="primary" size="small" @click="addTunnel">
            <el-icon><Plus /></el-icon>
            添加隧道
          </el-button>
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
import { ElMessage, ElMessageBox } from 'element-plus'
import { presetApi } from '@/api'

interface Tunnel {
  type: string
  Sport: number
  Cport: number
}

interface Preset {
  name: string
  note: string
  tunnel: Tunnel[]
}

const presets = ref<Preset[]>([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const editIndex = ref(-1)
const form = ref<Preset>({
  name: '',
  note: '',
  tunnel: []
})

const loadData = async () => {
  try {
    const res = await presetApi.list()
    presets.value = res.data.presets || []
  } catch (error) {
    ElMessage.error('加载数据失败')
  }
}

const handleAdd = () => {
  isEdit.value = false
  editIndex.value = -1
  form.value = { name: '', note: '', tunnel: [] }
  dialogVisible.value = true
}

const handleEdit = (index: number) => {
  isEdit.value = true
  editIndex.value = index
  form.value = JSON.parse(JSON.stringify(presets.value[index]))
  dialogVisible.value = true
}

const handleDelete = async (index: number) => {
  try {
    await ElMessageBox.confirm('确定要删除这个预设吗？', '提示', {
      type: 'warning'
    })
    presets.value.splice(index, 1)
    await saveData()
    ElMessage.success('删除成功')
  } catch (error) {
    // 用户取消
  }
}

const addTunnel = () => {
  form.value.tunnel.push({ type: 'tcp', Sport: 0, Cport: 0 })
}

const removeTunnel = (index: number) => {
  form.value.tunnel.splice(index, 1)
}

const handleSave = async () => {
  if (!form.value.name) {
    ElMessage.warning('请输入名称')
    return
  }
  if (form.value.tunnel.length === 0) {
    ElMessage.warning('请至少添加一个隧道配置')
    return
  }

  if (isEdit.value) {
    presets.value[editIndex.value] = JSON.parse(JSON.stringify(form.value))
  } else {
    presets.value.push(JSON.parse(JSON.stringify(form.value)))
  }

  await saveData()
  dialogVisible.value = false
  ElMessage.success('保存成功')
}

const saveData = async () => {
  try {
    await presetApi.save({ presets: presets.value })
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(loadData)
</script>

<style scoped>
.presets-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
