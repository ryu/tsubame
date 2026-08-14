// Scroll an element into view only when it sits outside its container's viewport,
// so navigating within the visible range doesn't jump the list around.
export function scrollIntoViewIfNeeded(element, container) {
  const elementRect = element.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()

  if (elementRect.top < containerRect.top) {
    element.scrollIntoView({ block: "start", behavior: "smooth" })
  } else if (elementRect.bottom > containerRect.bottom) {
    element.scrollIntoView({ block: "end", behavior: "smooth" })
  }
}
