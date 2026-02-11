// Open the Hatena Bookmark page for the given URL in a new tab.
// Only http/https URLs are accepted.
export function openHatenaBookmarkPage(url) {
  if (!url) return

  let bookmarkUrl
  try {
    const urlObj = new URL(url)

    if (urlObj.protocol !== "http:" && urlObj.protocol !== "https:") {
      console.warn("Invalid protocol for Hatena Bookmark:", urlObj.protocol)
      return
    }

    if (urlObj.protocol === "https:") {
      bookmarkUrl = `https://b.hatena.ne.jp/entry/s/${urlObj.host}${urlObj.pathname}${urlObj.search}${urlObj.hash}`
    } else {
      bookmarkUrl = `https://b.hatena.ne.jp/entry/${url}`
    }
  } catch (error) {
    console.warn("Invalid URL for Hatena Bookmark:", url, error)
    return
  }

  window.open(bookmarkUrl, "_blank", "noopener,noreferrer")
}
