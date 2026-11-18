class_name ChallengeSchedule
extends RefCounted
## Deterministic daily/weekly challenge selection from a UTC timestamp.
## The timestamp source matters: the device clock can be changed by the player, so local
## scheduling is NOT secure. When GameHub provides authoritative time / schedules
## (GameHubAdapter.get_server_time / fetch_challenges), those must be used instead.


static func day_index(unix: int) -> int:
	return floori(unix / 86400.0)


## "D2026-11-11"
static func daily_key(unix: int) -> String:
	return "D" + Time.get_date_string_from_unix_time(unix)


## Weeks start on Monday (UTC). Key = "W" + the Monday's date.
static func weekly_key(unix: int) -> String:
	var d := day_index(unix)
	var weekday_mon0 := posmod(d + 3, 7) # 1970-01-01 was a Thursday
	return "W" + Time.get_date_string_from_unix_time((d - weekday_mon0) * 86400)


static func pick(pool: Array[ChallengeDef], key: String) -> ChallengeDef:
	if pool.is_empty():
		return null
	return pool[posmod(hash(key), pool.size())]


## Seconds until the current daily / weekly period rolls over.
static func seconds_left(unix: int, weekly: bool) -> int:
	var d := day_index(unix)
	var end_day := d + 1
	if weekly:
		end_day = d - posmod(d + 3, 7) + 7
	return end_day * 86400 - unix
