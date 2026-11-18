class_name EconomyConfig
extends Resource
## Match economy formulas. All values provisional until Phase 7 balancing.

@export var wave_reward_base: int = 20
@export var wave_reward_per_wave: int = 4 ## reward = base + per_wave * wave_number (1-based)
@export var passive_amount: int = 5
@export var passive_interval: float = 10.0 ## only ticks while a wave is active
@export var early_bonus_per_second: float = 1.5
@export var early_bonus_cap: int = 30
@export var sell_refund_ratio: float = 0.70
@export var kill_bounty_ratio: float = 0.90 ## game default is 0.90 in economy_default.tres (-10% total bounty / -5% further)
@export var seed_money_multiplier: float = 1.0 ## game default is 1.10 in economy_default.tres (+10% seed money)


func kill_bounty(base_bounty: int) -> int:
	if base_bounty <= 0:
		return 0
	return maxi(1, int(round(base_bounty * kill_bounty_ratio)))


func seed_money(base_money: int) -> int:
	return int(round(base_money * seed_money_multiplier))


func wave_reward(wave_number: int) -> int:
	return wave_reward_base + wave_reward_per_wave * wave_number


func early_bonus(remaining_seconds: float) -> int:
	return mini(int(floor(maxf(remaining_seconds, 0.0) * early_bonus_per_second)), early_bonus_cap)


func sell_refund(total_invested: int) -> int:
	return int(floor(total_invested * sell_refund_ratio))
