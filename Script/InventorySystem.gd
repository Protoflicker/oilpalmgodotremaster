extends Node

class_name InventorySystem

# Ubah dari float menjadi integer (bilangan bulat)
var delivered_ripe_kg: int = 0
var collected_unripe_kg: int = 0

signal permanent_inventory_updated(delivered_ripe_kg, collected_unripe_kg)

func _ready():
	add_to_group("inventory_system")

# Fungsi untuk menambah buah mentah (langsung dalam kg)
func add_unripe_fruit_kg(weight_kg: float):
	collected_unripe_kg += int(weight_kg)  # Konversi ke integer
	permanent_inventory_updated.emit(delivered_ripe_kg, collected_unripe_kg)

# Fungsi untuk menambah buah matang yang sudah diantar (dalam kg)
func add_delivered_ripe_kg(weight_kg: float):
	var weight_int = int(weight_kg)  # Konversi ke integer
	delivered_ripe_kg += weight_int
	permanent_inventory_updated.emit(delivered_ripe_kg, collected_unripe_kg)
	
	# Notify delivery zones about the new delivery
	notify_delivery_zones(weight_int)

func notify_delivery_zones(weight_kg: int):
	# Cari semua delivery zone dan update progres mereka
	var delivery_zones = get_tree().get_nodes_in_group("delivery_zone")
	for zone in delivery_zones:
		if zone.has_method("add_delivered_weight"):
			zone.add_delivered_weight(weight_kg)

func get_delivered_ripe_kg() -> int:
	return delivered_ripe_kg

func get_collected_unripe_kg() -> int:
	return collected_unripe_kg

func reset_inventory():
	delivered_ripe_kg = 0
	collected_unripe_kg = 0
	permanent_inventory_updated.emit(delivered_ripe_kg, collected_unripe_kg)
