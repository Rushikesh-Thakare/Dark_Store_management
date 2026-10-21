// One place for role names, descriptions and sidebar items; used by the home page and dashboard shell.
// Each nav item jumps to the element with that id on the role's dashboard page.
export const roles = {
  manager: {
    title: 'Manager',
    description: 'Track inventory, low-stock alerts, orders and reports.',
    nav: [
      { label: 'Store Overview', target: 'overview' },
      { label: 'Live Orders & Dispatch', target: 'orders-title' },
      { label: 'Inventory & Stock', target: 'inventory-title' },
      { label: 'Restock Alerts', target: 'alerts-title' },
      { label: 'Add / Edit SKU', target: 'product-form-title' },
    ],
  },
  rider: {
    title: 'Rider Partner',
    description: 'Dark store hub info, live customer orders, and active deliveries.',
    nav: [
      { label: 'Nearest Dark Store Hub', target: 'dark-store-hub' },
      { label: 'Live Customer Orders', target: 'live-customer-orders' },
      { label: 'My Assigned Deliveries', target: 'assigned-orders' },
      { label: 'Delivery History', target: 'delivery-history' },
    ],
  },
  customer: {
    title: 'Customer',
    description: 'Browse products, check stock, place orders and view history.',
    nav: [
      { label: 'Products', target: 'products-title' },
      { label: 'Express Cart', target: 'cart-title' },
      { label: 'Order History', target: 'history-title' },
    ],
  },
}

