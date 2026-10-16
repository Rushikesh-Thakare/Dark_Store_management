// One place for role names, descriptions and sidebar items; used by the home page and dashboard shell.
// Each nav item jumps to the element with that id on the role's dashboard page.
export const roles = {
  manager: {
    title: 'Manager',
    description: 'Track inventory, low-stock alerts, orders and reports.',
    nav: [
      { label: 'Overview', target: 'overview' },
      { label: 'Inventory', target: 'inventory-title' },
      { label: 'Restock alerts', target: 'alerts-title' },
      { label: 'Orders', target: 'orders-title' },
    ],
  },
  rider: {
    title: 'Rider',
    description: 'See your assigned deliveries and update their status.',
    nav: [{ label: 'Assigned orders', target: 'assigned-orders' }],
  },
  customer: {
    title: 'Customer',
    description: 'Browse products, check stock, place orders and view history.',
    nav: [
      { label: 'Products', target: 'products-title' },
      { label: 'Cart', target: 'cart-title' },
      { label: 'Order history', target: 'history-title' },
    ],
  },
}
