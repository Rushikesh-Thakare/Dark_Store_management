import { useState } from 'react'
import '../styles/product-form.css'

// Presentational form: it collects and checks the values, the parent does the saving.
// `initial` holds the starting values (empty for a new product, filled in when editing).
export default function ProductForm({ categories, initial, saving, error, message, onSubmit, onCancel }) {
  const [values, setValues] = useState(initial)
  const editing = initial.productId !== null
  const set = (field) => (event) => setValues({ ...values, [field]: event.target.value })

  function handleSubmit(event) {
    event.preventDefault()
    onSubmit({
      productId: initial.productId,
      categoryId: Number(values.categoryId),
      name: values.name.trim(),
      price: Number(values.price),
      stock: Number(values.stock),
      reorder: Number(values.reorder),
    })
  }

  // required / min / step / pattern use the browser's built-in validation, which blocks submit and
  // explains the problem. The database repeats the same checks, so they cannot be bypassed.
  return (
    <form className="product-form" onSubmit={handleSubmit}>
      <div className="form-grid">
        <div className="field">
          <label htmlFor="pf-category">Category</label>
          <select id="pf-category" required value={values.categoryId} onChange={set('categoryId')}>
            <option value="">Choose a category</option>
            {categories.map((category) => (
              <option key={category.category_id} value={category.category_id}>{category.category_name}</option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="pf-name">Product name</label>
          <input id="pf-name" type="text" required maxLength={150} pattern=".*\S.*" title="Enter a product name"
            value={values.name} onChange={set('name')} />
        </div>

        <div className="field">
          <label htmlFor="pf-price">Price (₹)</label>
          <input id="pf-price" type="number" required min="0.01" step="0.01" inputMode="decimal"
            value={values.price} onChange={set('price')} />
        </div>

        <div className="field">
          <label htmlFor="pf-stock">Stock</label>
          <input id="pf-stock" type="number" required min="0" step="1" inputMode="numeric"
            value={values.stock} onChange={set('stock')} />
        </div>

        <div className="field">
          <label htmlFor="pf-reorder">Reorder threshold</label>
          <input id="pf-reorder" type="number" required min="0" step="1" inputMode="numeric"
            value={values.reorder} onChange={set('reorder')} />
        </div>
      </div>

      {error && <p className="form-error" role="alert">{error}</p>}
      {message && <p className="form-success" role="status">{message}</p>}

      <div className="form-actions">
        <button type="submit" className="btn" disabled={saving}>
          {saving ? 'Saving…' : editing ? 'Save changes' : 'Add product'}
        </button>
        {editing && <button type="button" className="btn btn-ghost" disabled={saving} onClick={onCancel}>Cancel</button>}
      </div>
    </form>
  )
}
