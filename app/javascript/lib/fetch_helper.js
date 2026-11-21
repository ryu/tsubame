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

export function openInBackground(url) {
  const w = window.open(url, "_blank")
  window.focus()
  return w
}
