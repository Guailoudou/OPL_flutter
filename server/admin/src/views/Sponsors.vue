<template>
  <div class="sponsors-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>赞助列表管理</span>
          <el-button type="primary" @click="handleAdd">
            <el-icon><Plus /></el-icon>
            添加赞助记录
          </el-button>
        </div>
      </template>

      <el-table :data="sponsors" border stripe>
        <el-table-column prop="name" label="昵称" width="150" />
        <el-table-column prop="amount" label="金额" width="120">
          <template #default="{ row }">
            ¥{{ row.amount }}
          </template>
        </el-table-column>
        <el-table-column prop="time" label="时间" width="180" />
        <el-table-column prop="message" label="留言" show-overflow-tooltip />
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ $index }">
            <el-button type="primary" size="small" @click="handleEdit($index)">编辑</el-button>
            <el-button type="danger" size="small" @click="handleDelete($index)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="summary">
        <el-statistic title="赞助总额" :value="totalAmount" prefix="¥" />
        <el-statistic title="赞助人数" :value="sponsors.length" />
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑赞助记录' : '添加赞助记录'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="昵称">
          <el-input v-model="form.name" placeholder="赞助者昵称" />
        </el-form-item>
        <el-form-item label="金额">
          <el-input-number v-model="form.amount" :min="0" :precision="2" style="width: 100%" />
        </el-form-item>
        <el-form-item label="时间">
          <el-date-picker
            v-model="form.time"
            type="datetime"
            placeholder="选择赞助时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DD HH:mm:ss"
          />
        </el-form-item>
        <el-form-item label="留言">
          <el-input v-model="form.message" type="textarea" :rows="4" placeholder="赞助者留言" />
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
import { ElMessage, ElMessageBox } from 'element-plus'
import { sponsorApi } from '@/api'

interface Sponsor {
  name: string
  amount: number
  time: string
  message: string
}

const sponsors = ref<Sponsor[]>([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const editIndex = ref(-1)
const form = ref<Sponsor>({
  name: '',
  amount: 0,
  time: '',
  message: ''
})

const totalAmount = computed(() => {
  return sponsors.value.reduce((sum, item) => sum + item.amount, 0)
})

const loadData = async () => {
  try {
    const res = await sponsorApi.list()
    sponsors.value = res.data.sponsors || []
  } catch (error) {
    ElMessage.error('加载数据失败')
  }
}

const handleAdd = () => {
  isEdit.value = false
  editIndex.value = -1
  form.value = { name: '', amount: 0, time: '', message: '' }
  dialogVisible.value = true
}

const handleEdit = (index: number) => {
  isEdit.value = true
  editIndex.value = index
  form.value = JSON.parse(JSON.stringify(sponsors.value[index]))
  dialogVisible.value = true
}

const handleDelete = async (index: number) => {
  try {
    await ElMessageBox.confirm('确定要删除这条赞助记录吗？', '提示', {
      type: 'warning'
    })
    sponsors.value.splice(index, 1)
    await saveData()
    ElMessage.success('删除成功')
  } catch (error) {
    // 用户取消
  }
}

const handleSave = async () => {
  if (!form.value.name) {
    ElMessage.warning('请输入昵称')
    return
  }
  if (form.value.amount <= 0) {
    ElMessage.warning('请输入有效金额')
    return
  }
  if (!form.value.time) {
    ElMessage.warning('请选择时间')
    return
  }

  if (isEdit.value) {
    sponsors.value[editIndex.value] = JSON.parse(JSON.stringify(form.value))
  } else {
    sponsors.value.push(JSON.parse(JSON.stringify(form.value)))
  }

  await saveData()
  dialogVisible.value = false
  ElMessage.success('保存成功')
}

const saveData = async () => {
  try {
    await sponsorApi.save({ sponsors: sponsors.value })
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(loadData)
</script>

<style scoped>
.sponsors-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.summary {
  margin-top: 20px;
  display: flex;
  gap: 40px;
}
</style>
