<template>
  <div class="notices-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>公告管理</span>
          <el-button type="primary" @click="handleAdd">
            <el-icon><Plus /></el-icon>
            添加公告
          </el-button>
        </div>
      </template>

      <el-table :data="notices" border stripe>
        <el-table-column prop="title" label="标题" width="200" />
        <el-table-column prop="content" label="内容" show-overflow-tooltip />
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ $index }">
            <el-button type="primary" size="small" @click="handleEdit($index)">编辑</el-button>
            <el-button type="danger" size="small" @click="handleDelete($index)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑公告' : '添加公告'" width="600px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题">
          <el-input v-model="form.title" placeholder="公告标题" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input v-model="form.content" type="textarea" :rows="6" placeholder="公告内容" />
        </el-form-item>
        <el-form-item label="时间">
          <el-date-picker
            v-model="form.time"
            type="datetime"
            placeholder="选择发布时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DD HH:mm:ss"
          />
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
import { noticeApi } from '@/api'

interface Notice {
  title: string
  content: string
  time: string
}

const notices = ref<Notice[]>([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const editIndex = ref(-1)
const form = ref<Notice>({
  title: '',
  content: '',
  time: ''
})

const loadData = async () => {
  try {
    const res = await noticeApi.list()
    notices.value = res.data.notices || []
  } catch (error) {
    ElMessage.error('加载数据失败')
  }
}

const handleAdd = () => {
  isEdit.value = false
  editIndex.value = -1
  form.value = { title: '', content: '', time: '' }
  dialogVisible.value = true
}

const handleEdit = (index: number) => {
  isEdit.value = true
  editIndex.value = index
  form.value = JSON.parse(JSON.stringify(notices.value[index]))
  dialogVisible.value = true
}

const handleDelete = async (index: number) => {
  try {
    await ElMessageBox.confirm('确定要删除这个公告吗？', '提示', {
      type: 'warning'
    })
    notices.value.splice(index, 1)
    await saveData()
    ElMessage.success('删除成功')
  } catch (error) {
    // 用户取消
  }
}

const handleSave = async () => {
  if (!form.value.title) {
    ElMessage.warning('请输入标题')
    return
  }
  if (!form.value.content) {
    ElMessage.warning('请输入内容')
    return
  }
  if (!form.value.time) {
    ElMessage.warning('请选择时间')
    return
  }

  if (isEdit.value) {
    notices.value[editIndex.value] = JSON.parse(JSON.stringify(form.value))
  } else {
    notices.value.unshift(JSON.parse(JSON.stringify(form.value)))
  }

  await saveData()
  dialogVisible.value = false
  ElMessage.success('保存成功')
}

const saveData = async () => {
  try {
    await noticeApi.save({ notices: notices.value })
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(loadData)
</script>

<style scoped>
.notices-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
