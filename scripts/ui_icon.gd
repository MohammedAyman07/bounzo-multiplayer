extends Control
class_name UIIcon

# =====================================================
# UI ICON — Procedural Vector Icon Component
# Replaces emojis with clean, consistent vector graphics.
# =====================================================

enum Type {
	NONE,
	PLAY,
	BACK,
	HOME,
	SETTINGS,
	SHOP,
	DAILY,
	MISSIONS,
	COIN,
	LOCK,
	CHECK,
	PAUSE,
	RESTART,
	CHAIN,
	TROPHY,
	REWARD,
	MULTIPLAYER
}

@export var icon_type: Type = Type.NONE:
	set(v):
		icon_type = v
		queue_redraw()

@export var icon_color: Color = Color.WHITE:
	set(v):
		icon_color = v
		queue_redraw()

@export var icon_size: float = 24.0:
	set(v):
		icon_size = v
		custom_minimum_size = Vector2(v, v)
		queue_redraw()

func _init(t: Type = Type.NONE, c: Color = Color.WHITE, s: float = 24.0) -> void:
	icon_type = t
	icon_color = c
	icon_size = s
	custom_minimum_size = Vector2(s, s)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if icon_type == Type.NONE:
		return
		
	var center = size / 2.0
	var r = icon_size / 2.0
	
	match icon_type:
		Type.PLAY:
			var pts = PackedVector2Array([
				center + Vector2(-r * 0.4, -r * 0.6),
				center + Vector2(r * 0.6, 0),
				center + Vector2(-r * 0.4, r * 0.6)
			])
			draw_polygon(pts, PackedColorArray([icon_color, icon_color, icon_color]))
			
		Type.BACK:
			var w = r * 0.6
			draw_line(center + Vector2(w, 0), center + Vector2(-w, 0), icon_color, 2.0, true)
			draw_line(center + Vector2(-w, 0), center + Vector2(0, -w), icon_color, 2.0, true)
			draw_line(center + Vector2(-w, 0), center + Vector2(0, w), icon_color, 2.0, true)
			
		Type.HOME:
			var w = r * 0.6
			draw_line(center + Vector2(0, -w), center + Vector2(-w, 0), icon_color, 2.0, true)
			draw_line(center + Vector2(0, -w), center + Vector2(w, 0), icon_color, 2.0, true)
			draw_rect(Rect2(center.x - w * 0.6, center.y, w * 1.2, w * 0.8), icon_color, true)
			
		Type.SETTINGS:
			draw_circle(center, r * 0.4, icon_color)
			for i in range(8):
				var angle = i * PI / 4.0
				var p1 = center + Vector2(cos(angle), sin(angle)) * (r * 0.4)
				var p2 = center + Vector2(cos(angle), sin(angle)) * (r * 0.7)
				draw_line(p1, p2, icon_color, 3.0, true)
				
		Type.SHOP:
			var w = r * 0.6
			draw_line(center + Vector2(-w, -w), center + Vector2(-w * 0.6, -w), icon_color, 2.0, true)
			draw_line(center + Vector2(-w * 0.6, -w), center + Vector2(-w * 0.2, w * 0.4), icon_color, 2.0, true)
			draw_line(center + Vector2(-w * 0.2, w * 0.4), center + Vector2(w, w * 0.4), icon_color, 2.0, true)
			draw_line(center + Vector2(w, w * 0.4), center + Vector2(w * 0.8, -w * 0.2), icon_color, 2.0, true)
			draw_line(center + Vector2(w * 0.8, -w * 0.2), center + Vector2(-w * 0.4, -w * 0.2), icon_color, 2.0, true)
			draw_circle(center + Vector2(0, w * 0.8), r * 0.15, icon_color)
			draw_circle(center + Vector2(w * 0.6, w * 0.8), r * 0.15, icon_color)
			
		Type.DAILY:
			var w = r * 0.6
			draw_rect(Rect2(center.x - w, center.y - w * 0.6, w * 2, w * 1.6), icon_color, false, 2.0)
			draw_line(center + Vector2(-w * 0.6, -w), center + Vector2(-w * 0.6, -w * 0.4), icon_color, 2.0, true)
			draw_line(center + Vector2(w * 0.6, -w), center + Vector2(w * 0.6, -w * 0.4), icon_color, 2.0, true)
			draw_line(center + Vector2(-w, -w * 0.1), center + Vector2(w, -w * 0.1), icon_color, 2.0, true)
			
		Type.MISSIONS:
			var w = r * 0.6
			draw_circle(center, w, icon_color, false, 2.0)
			draw_circle(center, w * 0.5, icon_color, false, 2.0)
			draw_circle(center, w * 0.1, icon_color)
			
		Type.COIN:
			draw_circle(center, r * 0.8, icon_color)
			draw_circle(center, r * 0.5, Color(0, 0, 0, 0.4), false, 2.0)
			draw_rect(Rect2(center.x - r * 0.1, center.y - r * 0.3, r * 0.2, r * 0.6), Color(0, 0, 0, 0.4), true)
			
		Type.LOCK:
			var w = r * 0.5
			draw_rect(Rect2(center.x - w, center.y, w * 2, w * 1.2), icon_color, true)
			draw_arc(center + Vector2(0, 0), w * 0.6, PI, PI * 2, 16, icon_color, 2.0, true)
			
		Type.CHECK:
			var w = r * 0.6
			draw_line(center + Vector2(-w, 0), center + Vector2(-w * 0.2, w * 0.6), icon_color, 3.0, true)
			draw_line(center + Vector2(-w * 0.2, w * 0.6), center + Vector2(w, -w * 0.4), icon_color, 3.0, true)
			
		Type.PAUSE:
			var w = r * 0.4
			draw_rect(Rect2(center.x - w, center.y - r * 0.5, w * 0.6, r), icon_color, true)
			draw_rect(Rect2(center.x + w * 0.4, center.y - r * 0.5, w * 0.6, r), icon_color, true)
			
		Type.RESTART:
			var w = r * 0.6
			draw_arc(center, w, -PI * 0.8, PI * 0.8, 24, icon_color, 2.0, true)
			var arrow_tip = center + Vector2(cos(-PI * 0.8), sin(-PI * 0.8)) * w
			draw_line(arrow_tip, arrow_tip + Vector2(w * 0.4, w * 0.1), icon_color, 2.0, true)
			draw_line(arrow_tip, arrow_tip + Vector2(-w * 0.1, w * 0.4), icon_color, 2.0, true)
			
		Type.CHAIN:
			var w = r * 0.4
			draw_arc(center + Vector2(-w, w), w, PI * 0.25, PI * 1.25, 12, icon_color, 2.0, true)
			draw_arc(center + Vector2(w, -w), w, -PI * 0.75, PI * 0.25, 12, icon_color, 2.0, true)
			draw_line(center + Vector2(-w * 1.7, w * 0.3), center + Vector2(w * 0.3, -w * 1.7), icon_color, 2.0, true)
			draw_line(center + Vector2(-w * 0.3, w * 1.7), center + Vector2(w * 1.7, -w * 0.3), icon_color, 2.0, true)
			
		Type.TROPHY:
			var w = r * 0.5
			draw_rect(Rect2(center.x - w, center.y - w * 1.2, w * 2, w * 1.2), icon_color, true)
			draw_line(center + Vector2(-w, -w * 1.2), center + Vector2(w, -w * 1.2), icon_color, 2.0, true)
			draw_arc(center + Vector2(0, 0), w, 0, PI, 12, icon_color, 2.0, true)
			draw_line(center + Vector2(0, w), center + Vector2(0, w * 1.6), icon_color, 2.0, true)
			draw_line(center + Vector2(-w * 0.8, w * 1.6), center + Vector2(w * 0.8, w * 1.6), icon_color, 3.0, true)
			
		Type.REWARD:
			var w = r * 0.6
			draw_rect(Rect2(center.x - w, center.y - w * 0.8, w * 2, w * 1.6), icon_color, true)
			draw_line(center + Vector2(-w * 1.2, -w * 0.2), center + Vector2(w * 1.2, -w * 0.2), Color(0,0,0,0.5), 3.0, true)
			draw_line(center + Vector2(0, -w * 0.8), center + Vector2(0, w * 0.8), Color(0,0,0,0.5), 3.0, true)

		Type.MULTIPLAYER:
			# Universal dual-player silhouettes (two side-by-side gamer avatars)
			var w = r * 0.38
			var h = r * 0.58
			var p1_x = center.x - r * 0.42
			var p2_x = center.x + r * 0.42
			var head_y = center.y - r * 0.28
			var head_r = r * 0.27
			var body_base_y = center.y + r * 0.70
			
			# Draw heads
			draw_circle(Vector2(p1_x, head_y), head_r, icon_color)
			draw_circle(Vector2(p2_x, head_y), head_r, icon_color)
			
			# Draw torsos (smooth rounded shoulders)
			var steps = 12
			for px in [p1_x, p2_x]:
				var pts = PackedVector2Array()
				for i in range(steps + 1):
					var ang = -PI + (PI * float(i) / float(steps))
					pts.append(Vector2(px + cos(ang) * w, body_base_y + sin(ang) * h))
				pts.append(Vector2(px + w, body_base_y))
				pts.append(Vector2(px - w, body_base_y))
				draw_colored_polygon(pts, icon_color)

