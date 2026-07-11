import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 10000
})

// 预设隧道
export const presetApi = {
  list: () => api.get('/preset'),
  save: (data: any) => api.post('/preset', data)
}

// 公告
export const noticeApi = {
  list: () => api.get('/notices'),
  save: (data: any) => api.post('/notices', data)
}

// 赞助
export const sponsorApi = {
  list: () => api.get('/sponsors'),
  save: (data: any) => api.post('/sponsors', data)
}

// 版本
export const releaseApi = {
  get: () => api.get('/releases'),
  save: (data: any) => api.post('/releases', data)
}

// 核心
export const coreApi = {
  get: () => api.get('/core'),
  save: (data: any) => api.post('/core', data),
  getPlatform: (platform: string) => api.get(`/core/${platform}`),
  savePlatform: (platform: string, data: any) => api.post(`/core/${platform}`, data)
}

export default api
