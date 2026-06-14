# performancemonitor.gd - VERSI FINAL
extends Node

func _ready():
	print("✅ Performance Monitor Ready! Press SPACE to save performance data")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_CAPSLOCK:
		save_performance_data()

func save_performance_data():
	var data = "=== GODOT PERFORMANCE REPORT ===\n"
	data += "Time: " + Time.get_datetime_string_from_system() + "\n\n"
	
	# 🎯 PERFORMANCE CORE
	data += "FPS " + str(Engine.get_frames_per_second()) + "\n"
	data += "Process %.2f ms\n" % Performance.get_monitor(Performance.TIME_PROCESS)
	data += "Physics Process %.2f ms\n" % Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	data += "Navigation Process %.2f ms\n" % Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)
	
	# 💾 MEMORY USAGE
	data += "\nMemory\n"
	data += "Static %.2f MiB\n" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0)
	data += "Static Max %.2f MiB\n" % (Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0)
	data += "Msg Buf Max %.2f KiB\n" % (Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX) / 1024.0)
	
	# 🏷️ OBJECT COUNTS
	data += "\nObject\n"
	data += "Objects " + str(Performance.get_monitor(Performance.OBJECT_COUNT)) + "\n"
	data += "Resources " + str(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) + "\n"
	data += "Nodes " + str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) + "\n"
	data += "Orphan Nodes " + str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) + "\n"
	
	# 🎨 RENDER PERFORMANCE
	data += "\nRaster\n"
	data += "Total Objects Drawn " + str(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) + "\n"
	data += "Total Primitives Drawn " + str(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) + "\n"
	data += "Total Draw Calls " + str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) + "\n"
	
	# 🎮 VIDEO MEMORY
	data += "\nVideo\n"
	data += "Video Mem %.2f MiB\n" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0)
	data += "Texture Mem %.2f MiB\n" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1024.0 / 1024.0)
	data += "Buffer Mem %.2f MiB\n" % (Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1024.0 / 1024.0)
	
	# ⚙️ PHYSICS 3D
	data += "\nPhysics 3D\n"
	data += "Active Objects " + str(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)) + "\n"
	data += "Collision Pairs " + str(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)) + "\n"
	
	# 💾 Save to file - OPSI 1: res://Performance Report/
	var dir_path = "res://Performance Report/"
	var file_path = dir_path + "performance_report_" + Time.get_datetime_string_from_system().replace(":", "-") + ".txt"
	
	# Buat folder jika belum ada
	DirAccess.make_dir_absolute(dir_path)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(data)
		file.close()
		print("✅ Performance data saved!")
		print("📁 Location: " + file_path)
		
		# Buka folder (opsional)
		OS.shell_open(ProjectSettings.globalize_path(dir_path))
	else:
		print("❌ Error saving performance report!")
