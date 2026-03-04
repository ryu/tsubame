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

// Open a URL in a background tab using anchor click.
// Uses <a target="_blank"> navigation instead of window.open() to avoid
// popup blocker restrictions in Safari 26+.
export function openInBackground(url) {
  const a = document.createElement("a")
  a.href = url
  a.target = "_blank"
  a.rel = "noopener"
  document.body.appendChild(a)
  a.click()
  a.remove()
  window.focus()
}
