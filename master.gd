## Manages the demo storefront and its billing interface.
class_name Master
extends Control

const COLOR_DISCONNECTED: Color = Color("d32f2f")
const COLOR_CONNECTING: Color = Color("f57c00")
const COLOR_CONNECTED: Color = Color("388e3c")
const PURCHASE_LOG_LINES: int = 3

var user_gold: int = 0
var owned_ids: Array[String] = []
var purchase_log_entries: Array[String] = []
var connection_status_tween: Tween

@onready var connection_status_label: Label = %ConnectionStatusDataLabel
@onready var connection_status_color_rect: ColorRect = %ConnectionStatusColorRect
@onready var debug_rich_text_label: RichTextLabel = %DebugRichTextLabel

@onready var gold_100_name_label: Label = %Gold100NameLabel
@onready var gold_500_name_label: Label = %Gold500NameLabel
@onready var gold_amount_label: Label = %GoldAmountLabel
@onready var gold_100_button: Button = %Gold100Button
@onready var gold_500_button: Button = %Gold500Button
@onready var starter_pack_button: Button = %StarterPackButton
@onready var starter_pack_name_label: Label = %StarterPackLabel
@onready var vip_pass_button: Button = %VipPassButton
@onready var vip_pass_name_label: Label = (
	$VBoxContainer/AknowledgementMarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VipPassLabel
)
@onready var sub_name_label: Label = %SubNameLabel
@onready var sub_desc_label: Label = %SubDescLabel
@onready var sub_price_label: Label = %SubPriceLabel
@onready var no_ads_sub_button: Button = %NoAdsSubscriptionButton
@onready var already_subscribed_label: ColorRect = %Subscribed
@onready var billing_handler: BillingHandler = %BillingHandler


func _on_billing_handler_connection_status_changed(status: int) -> void:
	var status_text: String
	var status_color: Color

	match status:
		BillingHandler.ConnectionStatus.DISCONNECTED:
			status_text = "Disconnected"
			status_color = COLOR_DISCONNECTED
		BillingHandler.ConnectionStatus.CONNECTING:
			status_text = "Connecting"
			status_color = COLOR_CONNECTING
		BillingHandler.ConnectionStatus.CONNECTED:
			status_text = "Connected"
			status_color = COLOR_CONNECTED
		_:
			return

	connection_status_label.text = status_text
	connection_status_label.modulate = Color.WHITE
	if connection_status_tween and connection_status_tween.is_running():
		connection_status_tween.kill()
	connection_status_tween = create_tween()
	connection_status_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	connection_status_tween.tween_property(connection_status_color_rect, "color", status_color, 0.35)


## Updates the storefront after a purchase completes.
func _on_billing_handler_purchase_completed(product_id: String) -> void:
	_add_purchase_log_entry(product_id)
	match product_id:
		"gold_100":
			user_gold += 100
			gold_amount_label.text = "Gold: " + str(user_gold)
		"gold_500":
			user_gold += 500
			gold_amount_label.text = "Gold: " + str(user_gold)
		"vip_pass":
			vip_pass_button.disabled = true
			vip_pass_button.modulate = COLOR_CONNECTED
			vip_pass_button.text = "Purchased"
			owned_ids.append(product_id)
		"starter_bundle":
			starter_pack_button.disabled = true
			starter_pack_button.modulate = COLOR_CONNECTED
			starter_pack_button.text = "Purchased"
			owned_ids.append(product_id)
		"no_ads_sub":
			no_ads_sub_button.visible = false
			already_subscribed_label.color = COLOR_CONNECTED
			already_subscribed_label.visible = true
			owned_ids.append(product_id)

func _on_billing_handler_purchase_already_owned(response: Dictionary) -> void:
	var product_id: String = str(response.get("product_id", ""))
	_add_purchase_log_entry("Purchase already owned: %s" % [product_id])


func _add_purchase_log_entry(product_id: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	purchase_log_entries.push_front("%s INFO: %s" % [timestamp, product_id])
	if purchase_log_entries.size() > PURCHASE_LOG_LINES:
		purchase_log_entries.pop_back()
	debug_rich_text_label.text = "\n".join(purchase_log_entries)


## Displays product details when billing makes a product available.
func _on_billing_handler_new_product_avalaible(product_id: String) -> void:
	var product: Dictionary = billing_handler.get_product(product_id)
	match product_id:
		"gold_100":
			_apply_gold_100_product_data(product)
			gold_100_button.disabled = false
		"gold_500":
			_apply_gold_500_product_data(product)
			gold_500_button.disabled = false
		"vip_pass":
			_apply_vip_pass_rental_product_data(product)
		"starter_bundle":
			_apply_starter_pack_product_data(product)
		"no_ads_sub":
			_apply_subscription_product_data(product)


func _apply_gold_100_product_data(product: Dictionary) -> void:
	if product.is_empty():
		return

	var product_name: String = str(product.get("name", ""))
	if product_name.is_empty():
		product_name = str(product.get("title", ""))
	gold_100_name_label.text = product_name

	var offer: Dictionary = {}
	var offers: Array = product.get("one_time_purchase_offer_details_list", [])
	if not offers.is_empty():
		offer = offers[0]
	else:
		offer = product.get("one_time_purchase_offer_details", {})
	var formatted_price: String = str(
		offer.get("formatted_price", product.get("formatted_price", ""))
	)
	var currency_code: String = str(
		offer.get("price_currency_code", product.get("price_currency_code", ""))
	)
	if not formatted_price.is_empty() and not currency_code.is_empty():
		gold_100_button.text = "%s %s" % [formatted_price, currency_code]
	else:
		gold_100_button.text = formatted_price


func _apply_gold_500_product_data(product: Dictionary) -> void:
	if product.is_empty():
		return

	var product_name: String = str(product.get("name", ""))
	if product_name.is_empty():
		product_name = str(product.get("title", ""))
	gold_500_name_label.text = product_name

	var offer: Dictionary = {}
	var offers: Array = product.get("one_time_purchase_offer_details_list", [])
	if not offers.is_empty():
		offer = offers[0]
	else:
		offer = product.get("one_time_purchase_offer_details", {})
	var formatted_price: String = str(
		offer.get("formatted_price", product.get("formatted_price", ""))
	)
	var currency_code: String = str(
		offer.get("price_currency_code", product.get("price_currency_code", ""))
	)
	if not formatted_price.is_empty() and not currency_code.is_empty():
		gold_500_button.text = "%s %s" % [formatted_price, currency_code]
	else:
		gold_500_button.text = formatted_price


func _apply_vip_pass_rental_product_data(product: Dictionary) -> void:
	if product.is_empty():
		return

	var product_name: String = str(product.get("name", ""))
	if product_name.is_empty():
		product_name = str(product.get("title", ""))
	vip_pass_name_label.text = product_name

	if "vip_pass" in owned_ids:
		return

	var offers: Array = product.get("one_time_purchase_offer_details_list", [])
	var offer: Dictionary = (
		offers[0] if not offers.is_empty() else product.get("one_time_purchase_offer_details", {})
	)
	var formatted_price: String = str(
		offer.get("formatted_price", product.get("formatted_price", ""))
	)
	var currency_code: String = str(
		offer.get("price_currency_code", product.get("price_currency_code", ""))
	)
	if not formatted_price.is_empty() and not currency_code.is_empty():
		vip_pass_button.text = "%s %s" % [formatted_price, currency_code]
	else:
		vip_pass_button.text = formatted_price
	vip_pass_button.disabled = false


func _apply_starter_pack_product_data(product: Dictionary) -> void:
	if product.is_empty():
		return

	var product_name: String = str(product.get("name", ""))
	if product_name.is_empty():
		product_name = str(product.get("title", ""))
	starter_pack_name_label.text = product_name

	if "starter_bundle" in owned_ids:
		return

	var offers: Array = product.get("one_time_purchase_offer_details_list", [])
	var offer: Dictionary = (
		offers[0] if not offers.is_empty() else product.get("one_time_purchase_offer_details", {})
	)
	var formatted_price: String = str(
		offer.get("formatted_price", product.get("formatted_price", ""))
	)
	var currency_code: String = str(
		offer.get("price_currency_code", product.get("price_currency_code", ""))
	)
	if not formatted_price.is_empty() and not currency_code.is_empty():
		starter_pack_button.text = "%s %s" % [formatted_price, currency_code]
	else:
		starter_pack_button.text = formatted_price
	starter_pack_button.disabled = false


func _apply_subscription_product_data(product: Dictionary) -> void:
	if product.is_empty():
		return

	var product_name: String = str(product.get("name", ""))
	if product_name.is_empty():
		product_name = str(product.get("title", ""))
	if not product_name.is_empty():
		sub_name_label.text = product_name

	var product_desc: String = str(product.get("description", ""))
	if product_desc.is_empty():
		product_desc = str(product.get("title", ""))
	sub_desc_label.text = product_desc

	var product_price: String = ""
	var offer_details: Array = product.get("subscription_offer_details", [])
	if not offer_details.is_empty():
		var pricing_phases: Array = offer_details[0].get("pricing_phases", [])
		if not pricing_phases.is_empty():
			var phase: Dictionary = pricing_phases[0]
			var formatted_price: String = str(phase.get("formatted_price", ""))
			var currency_code: String = str(phase.get("price_currency_code", ""))
			if not formatted_price.is_empty():
				product_price = formatted_price
				if (
					not currency_code.is_empty()
					and not product_price.to_upper().contains(currency_code.to_upper())
				):
					product_price = "%s %s" % [formatted_price, currency_code]

	if product_price.is_empty():
		product_price = str(product.get("formatted_price", ""))
	if not product_price.is_empty():
		sub_price_label.text = product_price

	if "no_ads_sub" in owned_ids:
		return

	no_ads_sub_button.disabled = false


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_gold_100_button_pressed() -> void:
	billing_handler.buy_product("gold_100")


func _on_gold_500_button_pressed() -> void:
	billing_handler.buy_product("gold_500")


func _on_vip_pass_button_pressed() -> void:
	billing_handler.buy_product("vip_pass")


func _on_starter_pack_button_pressed() -> void:
	billing_handler.buy_product("starter_bundle")


func _on_no_ads_subscription_button_pressed() -> void:
	billing_handler.buy_subscription("no_ads_sub", "monthly-plan-no-ads")


func _on_about_button_pressed() -> void:
	get_tree().change_scene_to_file("res://about.tscn")
