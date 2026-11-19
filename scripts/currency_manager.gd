extends Node

# =====================================================
# CURRENCY MANAGER
# Manages the coin economy and interfaces with SaveManager
# Registered as Autoload "CurrencyManager" in project.godot.
# =====================================================

signal coins_changed(new_amount)


func get_coins() -> int:
	return SaveManager.data.get("coins", 0)

func set_coins(amount: int) -> void:
	var clamped_amt = clampi(amount, 0, 999999999)
	SaveManager.data["coins"] = clamped_amt
	SaveManager.save_data()
	coins_changed.emit(clamped_amt)

func add_coins(amount: int) -> void:
	if amount > 0:
		set_coins(get_coins() + amount)

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	if can_afford(amount):
		set_coins(get_coins() - amount)
		return true
	return false

func can_afford(amount: int) -> bool:
	if amount <= 0:
		return false
	return get_coins() >= amount
