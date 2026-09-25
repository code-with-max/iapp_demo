class_name BillingHandler
extends Node

## High-level manager for Google Play Billing operations and purchase state.

## Emitted when the billing connection status changes.
signal connection_status_changed(status: int)

## Emitted when a new product becomes available after querying details.
signal new_product_available(product_id: String)

## Backward-compatible signal for existing project bindings.
signal new_product_avalaible(product_id: String)

## Emitted when a purchase (consumable, non-consumable, or subscription) is completed.
signal purchase_completed(product_id: String)

## Emitted when Google Play rejects a purchase because the user already owns the item.
signal purchase_already_owned(response: Dictionary)

## Represents the current connection state to Google Play Billing.
enum ConnectionStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
}

const LOG_TAG: String = "BillingHandler"

const PRODUCTS_CONSUMABLE: Array[String] = ["gold_100", "gold_500"]
const PRODUCTS_NON_CONSUMABLE: Array[String] = ["starter_bundle", "vip_pass"]
const PRODUCTS_SUBSCRIPTION: Array[String] = ["no_ads_sub"]

## Reference to the GooglePlayBilling wrapper node.
@export var billing: GooglePlayBilling = null

## List of all available product details dictionaries.
var available_products: Array[Dictionary] = []

## Cached in-app products details.
var inapp_products: Array[Dictionary] = []

## Cached subscription products details.
var subscription_products: Array[Dictionary] = []

## Cached product dictionaries indexed by product ID.
var _products_by_id: Dictionary = {}

## Pending purchases mapping: purchase_token -> product_id.
var _pending_purchases: Dictionary = {}

func _ready() -> void:
	_setup_billing()
	_connect_billing_signals()


## Initiates the purchase flow for a product by its ID.
func buy_product(product_id: String) -> void:
	if not is_ready():
		return

	billing.buy_inapp(product_id)


## Initiates the purchase flow for a subscription.
func buy_subscription(
	product_id: String,
	base_plan_id: String,
	offer_id: String = "",
	is_personalized: bool = false
) -> void:
	if not is_ready():
		return

	billing.buy_subs(product_id, base_plan_id, offer_id, is_personalized)


## Returns cached product details for the given product ID, or an empty Dictionary if not found.
func get_product(product_id: String) -> Dictionary:
	return _products_by_id.get(product_id, {})


## Checks whether GooglePlayBilling is valid and ready to perform operations.
func is_ready() -> bool:
	return billing != null and billing.is_ready()


## Processes a purchase record and consumes or acknowledges it when required.
func process_purchase(purchase: Dictionary) -> void:
	var token: String = str(purchase.get("purchase_token", ""))
	if token.is_empty():
		LoggerGlobal.warning(LOG_TAG, "Purchase record is missing 'purchase_token', skipping.")
		return

	var products_list: Array = purchase.get("products", [])
	var product_id: String = str(products_list[0]) if not products_list.is_empty() else "unknown"
	var purchase_state: int = int(
		purchase.get("purchase_state", GooglePlayBilling.PurchaseState.UNSPECIFIED_STATE)
	)

	match purchase_state:
		GooglePlayBilling.PurchaseState.PURCHASED:
			_pending_purchases[token] = product_id
			if product_id in PRODUCTS_CONSUMABLE:
				billing.consume(token)
			elif product_id in PRODUCTS_NON_CONSUMABLE or product_id in PRODUCTS_SUBSCRIPTION:
				_process_acknowledge(purchase)
			else:
				_pending_purchases.erase(token)
				LoggerGlobal.warning(
					LOG_TAG,
					"Unknown product ID '%s', skipping consume/acknowledge." % product_id
				)

		GooglePlayBilling.PurchaseState.PENDING:
			_pending_purchases[token] = product_id

		_:
			LoggerGlobal.warning(
				LOG_TAG,
				"Unhandled purchase_state=%d for product '%s'." % [purchase_state, product_id]
			)


func _setup_billing() -> void:
	if not billing:
		billing = get_tree().root.find_child("GooglePlayBilling", true, false) as GooglePlayBilling
		if not billing:
			billing = GooglePlayBilling.new()
			add_child(billing)

	if not billing:
		LoggerGlobal.error(LOG_TAG, "Failed to find or create GooglePlayBilling node.")


func _connect_billing_signals() -> void:
	if not billing:
		return

	if not billing.iap_connection_starting.is_connected(_on_google_play_billing_connection_starting):
		billing.iap_connection_starting.connect(_on_google_play_billing_connection_starting)
	if not billing.iap_connected.is_connected(_on_google_play_billing_connected):
		billing.iap_connected.connect(_on_google_play_billing_connected)
	if not billing.iap_disconnected.is_connected(_on_google_play_billing_disconnected):
		billing.iap_disconnected.connect(_on_google_play_billing_disconnected)
	if not billing.iap_product_details_received.is_connected(
		_on_google_play_billing_product_details_received
	):
		billing.iap_product_details_received.connect(_on_google_play_billing_product_details_received)
	if not billing.iap_purchases_queried.is_connected(_on_google_play_billing_purchases_queried):
		billing.iap_purchases_queried.connect(_on_google_play_billing_purchases_queried)
	if not billing.iap_purchases_updated.is_connected(_on_google_play_billing_purchases_updated):
		billing.iap_purchases_updated.connect(_on_google_play_billing_purchases_updated)
	if not billing.iap_consumed_success.is_connected(_on_google_play_billing_consumed_success):
		billing.iap_consumed_success.connect(_on_google_play_billing_consumed_success)
	if not billing.iap_acknowledged_success.is_connected(_on_google_play_billing_acknowledged_success):
		billing.iap_acknowledged_success.connect(_on_google_play_billing_acknowledged_success)
	if not billing.iap_error_occurred.is_connected(_on_google_play_billing_error_occurred):
		billing.iap_error_occurred.connect(_on_google_play_billing_error_occurred)


func _process_acknowledge(purchase: Dictionary) -> void:
	var token: String = str(purchase.get("purchase_token", ""))
	var products_list: Array = purchase.get("products", [])
	var product_id: String = str(products_list[0]) if not products_list.is_empty() else "unknown"

	if purchase.get("is_acknowledged", false):
		_pending_purchases.erase(token)
		purchase_completed.emit(product_id)
		return

	_pending_purchases[token] = product_id
	billing.acknowledge(token)


func _on_google_play_billing_connection_starting() -> void:
	connection_status_changed.emit(ConnectionStatus.CONNECTING)


func _on_google_play_billing_connected() -> void:
	connection_status_changed.emit(ConnectionStatus.CONNECTED)

	billing.query_details(PRODUCTS_CONSUMABLE + PRODUCTS_NON_CONSUMABLE, GooglePlayBilling.TYPE_INAPP)
	billing.query_details(PRODUCTS_SUBSCRIPTION, GooglePlayBilling.TYPE_SUBS)
	billing.query_purchases(GooglePlayBilling.TYPE_INAPP)
	billing.query_purchases(GooglePlayBilling.TYPE_SUBS)


func _on_google_play_billing_disconnected() -> void:
	connection_status_changed.emit(ConnectionStatus.DISCONNECTED)


func _on_google_play_billing_product_details_received(
	products: Array[Dictionary],
	_unfetched: Array[Dictionary],
	type: String
) -> void:
	if type == GooglePlayBilling.TYPE_SUBS:
		subscription_products = products.duplicate(true)
	else:
		inapp_products = products.duplicate(true)

	for product: Dictionary in products:
		var product_id: String = str(product.get("product_id", ""))
		if product_id.is_empty():
			continue

		var is_new_product: bool = not _products_by_id.has(product_id)
		_products_by_id[product_id] = product
		if is_new_product:
			available_products.append(product)
			new_product_available.emit(product_id)
			new_product_avalaible.emit(product_id)


func _on_google_play_billing_purchases_queried(purchases: Array[Dictionary]) -> void:
	for purchase: Dictionary in purchases:
		process_purchase(purchase)


func _on_google_play_billing_purchases_updated(purchases: Array[Dictionary]) -> void:
	for purchase: Dictionary in purchases:
		process_purchase(purchase)


func _on_google_play_billing_consumed_success(token: String) -> void:
	var product_id: String = str(_pending_purchases.get(token, "unknown"))
	_pending_purchases.erase(token)
	purchase_completed.emit(product_id)


func _on_google_play_billing_acknowledged_success(token: String) -> void:
	var product_id: String = str(_pending_purchases.get(token, "unknown"))
	_pending_purchases.erase(token)
	purchase_completed.emit(product_id)


func _on_google_play_billing_error_occurred(fun_name: String, response: Dictionary) -> void:
	if (
		fun_name == "purchase_update"
		and int(response.get("response_code", -1))
		== GooglePlayBilling.BillingResponseCode.ITEM_ALREADY_OWNED
	):
		purchase_already_owned.emit(response)
		return

	LoggerGlobal.error(
		LOG_TAG,
		"Error in GooglePlayBilling function '%s': %s" % [fun_name, str(response)]
	)
