extends SceneTree
func _init():
	var cfg = ConfigFile.new()
	cfg.load('res://addons/AdmobPlugin/android_export.cfg')
	print('VAL:', cfg.get_value('Debug', 'app_id'))
	quit()

