function eventParts(event) {
  var parts = null
  try {
    if (event && event.parse) parts = event.parse(2)
  } catch (e) {}
  if (parts && parts.length >= 2) return [String(parts[0] || ""), String(parts[1] || "")]

  var data = String(event && event.data ? event.data : "")
  var comma = data.indexOf(",")
  if (comma < 0) return [data, ""]
  return [data.substring(0, comma), data.substring(comma + 1)]
}

function isTypedKeyboard(name) {
  return !/^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)/.test(String(name || ""))
}

function friendlyName(description) {
  var s = String(description || "").trim()
  if (!s) return "Keyboard"
  // Keep meaningful script/variant names, but make common names compact enough for a bar.
  if (/^English \(/.test(s)) return "English"
  if (/^Persian(?: \(|$)/.test(s)) return "Persian"
  if (/^Arabic(?: \(|$)/.test(s)) return "Arabic"
  if (/^French(?: \(|$)/.test(s)) return "French"
  if (/^German(?: \(|$)/.test(s)) return "German"
  if (/^Spanish(?: \(|$)/.test(s)) return "Spanish"
  if (/^Russian(?: \(|$)/.test(s)) return "Russian"
  if (/^Turkish(?: \(|$)/.test(s)) return "Turkish"
  if (/^Chinese(?: \(|$)/.test(s)) return "Chinese"
  if (/^Japanese(?: \(|$)/.test(s)) return "Japanese"
  if (/^Korean(?: \(|$)/.test(s)) return "Korean"
  return s.length > 18 ? s.substring(0, 17) + "…" : s
}

function initials(description) {
  var name = friendlyName(description)
  if (name === "Persian") return "FA"
  if (name === "English") return "EN"
  if (name === "Arabic") return "AR"
  if (name === "German") return "DE"
  if (name === "French") return "FR"
  if (name === "Spanish") return "ES"
  if (name === "Russian") return "RU"
  if (name === "Turkish") return "TR"
  var words = name.split(/\s+/).filter(Boolean)
  if (words.length > 1) return (words[0][0] + words[1][0]).toUpperCase()
  return name.substring(0, 2).toUpperCase()
}

function filteredAvailable(available, enabled, query, limit) {
  var q = String(query || "").trim().toLowerCase()
  var enabledCodes = {}
  ;(enabled || []).forEach(function (x) { if (x && x.code) enabledCodes[String(x.code)] = true })
  var out = []
  ;(available || []).forEach(function (item) {
    if (!item || !item.code || enabledCodes[String(item.code)]) return
    var hay = (String(item.name || "") + " " + String(item.code || "")).toLowerCase()
    if (q && hay.indexOf(q) < 0) return
    out.push(item)
  })
  return out.slice(0, limit || 12)
}

if (typeof module !== "undefined") {
  module.exports = { eventParts, isTypedKeyboard, friendlyName, initials, filteredAvailable }
}
