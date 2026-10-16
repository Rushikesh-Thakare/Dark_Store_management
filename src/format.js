export const formatMoney = (amount) => Number(amount).toLocaleString('en-IN', { style: 'currency', currency: 'INR' })
export const formatDate = (iso) => new Date(iso).toLocaleString()
export const formatStatus = (status) => status.replaceAll('_', ' ')
