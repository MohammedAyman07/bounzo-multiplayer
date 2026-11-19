extends Node

# =====================================================
# GAME EVENTS
# Global event bus for decoupled systems (Phase 4).
# Registered as Autoload "GameEvents" in project.godot.
# =====================================================

signal run_started
signal run_completed
signal platform_landed(is_perfect: bool)
signal score_changed(new_total: int, amount_gained: int)
signal chain_changed(new_chain: int)
signal coins_earned(amount: int)
signal new_best_score_reached(score: int)
signal new_best_chain_reached(chain: int)
signal risk_bonus_earned(position: Vector2)
