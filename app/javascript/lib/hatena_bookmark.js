// Build the Hatena Bookmark page URL for a given entry URL.
// Returns null for invalid URLs or non-http(s) protocols.
export function hatenaBookmarkUrl(url) {
  if (!url) return null

  try {
    const urlObj = new URL(url)

    if (urlObj.protocol !== "http:" && urlObj.protocol !== "https:") {
      console.warn("Invalid protocol for Hatena Bookmark:", urlObj.protocol)
      return null
    }

    if (urlObj.protocol === "https:") {
      return `https://b.hatena.ne.jp/entry/s/${urlObj.host}${urlObj.pathname}${urlObj.search}${urlObj.hash}`
    } else {
      return `https://b.hatena.ne.jp/entry/${url}`
    }
  } catch (error) {
    console.warn("Invalid URL for Hatena Bookmark:", url, error)
    return null
  }
}

// Open the Hatena Bookmark page for the given URL in a new tab.
export function openHatenaBookmarkPage(url) {
  const bookmarkUrl = hatenaBookmarkUrl(url)
  if (bookmarkUrl) window.open(bookmarkUrl, "_blank", "noopener,noreferrer")
}
