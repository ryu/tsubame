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

// POST/DELETE that answers with a Turbo Stream, rendered on arrival
export function submitTurboStream(url, options = {}) {
  return fetchWithCsrf(url, {
    method: "POST",
    ...options,
    headers: { "Accept": "text/vnd.turbo-stream.html", ...options.headers }
  })
    .then(response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.text()
    })
    .then(html => Turbo.renderStreamMessage(html))
}

// Open a URL in a background tab (works in Chrome/Firefox; Safari requires
// unchecking "When a new tab or window opens, make it active" in settings)
export function openInBackground(url) {
  const w = window.open(url, "_blank")
  window.focus()
  return w
}
