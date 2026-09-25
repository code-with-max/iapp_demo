class_name About
extends Control

## Сцена с информацией о приложении, используемом игровом движке и модуле покупок.


const LOG_PREFIX: String = "ABOUT"


# Инициализация узла при входе в дерево сцены
func _ready() -> void:
	# Логирование готовности сцены
	LoggerGlobal.info(LOG_PREFIX, "About scene ready")


# Обработка нажатия кнопки перехода по ссылке на Godot Engine
func _on_engine_link_button_pressed() -> void:
	# Логирование перехода по ссылке
	LoggerGlobal.info(LOG_PREFIX, "Opening Godot Engine website")

	# Открытие официального сайта движка в браузере
	_open_external_url("https://godotengine.org/")


# Обработка нажатия кнопки перехода по ссылке на репозиторий модуля покупок
func _on_plugin_link_button_pressed() -> void:
	# Логирование перехода по ссылке
	LoggerGlobal.info(LOG_PREFIX, "Opening Google Play Billing plugin repository")

	# Открытие страницы репозитория плагина в браузере
	_open_external_url("https://github.com/code-with-max/godot-google-play-iapp")


# Обработка нажатия кнопки возврата на главный экран
func _on_back_button_pressed() -> void:
	# Логирование действия возврата
	LoggerGlobal.info(LOG_PREFIX, "Returning to Master scene")

	# Переход на главную сцену приложения
	get_tree().change_scene_to_file("res://master.tscn")


# Вспомогательный метод безопасного открытия внешнего URL
func _open_external_url(url: String) -> void:
	# Проверка валидности переданного адреса
	if url.is_empty():
		return

	# Открытие ссылки в браузере операционной системы
	OS.shell_open(url)
