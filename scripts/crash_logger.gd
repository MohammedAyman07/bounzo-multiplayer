extends Node

# =====================================================
# BOUNZO CRASH LOGGER — uses OS.alert for visibility
# =====================================================

static func write(msg: String) -> void:
	print(msg)  # prints to logcat if ADB ever works

func _ready() -> void:
	# Show a native Android dialog — if user sees this, GDScript IS running
	OS.alert("Autoloads are running!\nStep 1: CrashLogger OK", "BOUNZO DEBUG")
