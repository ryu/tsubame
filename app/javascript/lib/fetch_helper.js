// Fetch helper with automatic CSRF token injection
export function fetchWithCsrf(url, options = {}) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  if (!csrfToken) {
    return Promise.reject(new Error("CSRF token not found"))
  }

  const headers = {
    "X-CSRF-Token": csrfToken,
    "Accept": "application/json",
    "Content-Type": "application/json",
    ...options.headers
  }

  return fetch(url, { ...options, headers })
}

// Open a URL in a background tab (works in Chrome/Firefox; Safari requires
// unchecking "When a new tab or window opens, make it active" in settings)
export function openInBackground(url) {
  window.open(url, "_blank", "noopener,noreferrer")
  window.focus()
}
