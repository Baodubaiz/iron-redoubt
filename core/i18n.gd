class_name I18n
extends RefCounted
## Translation helpers usable from static code. Keys are the English source strings; the
## Vietnamese table lives in res://i18n/translations.csv (imported by Godot).

const LANGUAGES := {"en": "English", "vi": "Tiếng Việt"}


static func t(s: String) -> String:
	return String(TranslationServer.translate(s))


## Translates a format string, then fills it: I18n.f("Wave %d/%d", [3, 8]).
static func f(fmt: String, args: Variant) -> String:
	return t(fmt) % args


## English is the default language (2026-11-19, user: Vietnamese is the optional second language).
## "auto" (the setting nobody has changed yet) = English, whatever the device language, EXCEPT on CrazyGames,
## whose requirements say translated games must follow the player's locale from the SDK (systemInfo.locale)
## and fall back to English: `platform_locale` is set from it there ("" elsewhere).
static var platform_locale := ""


static func resolve(setting: String) -> String:
	if setting == "en" or setting == "vi":
		return setting
	return platform_locale if platform_locale in ["en", "vi"] else "en"


## "vi-VN" / "vi" -> "vi"; anything else -> "en" (the only two languages shipped).
static func from_locale(locale: String) -> String:
	return "vi" if locale.to_lower().begins_with("vi") else "en"


static func apply(setting: String) -> void:
	TranslationServer.set_locale(resolve(setting))
