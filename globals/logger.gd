# logger.gd
extends Node

## Глобальный логгер (Autoload: LoggerGlobal)
##
## Централизованная система сбора, фильтрации и вывода логов.
## Все модули обращаются к LoggerGlobal для записи сообщений.
##
## ── Уровни логирования ──
##   LogLevel.DEBUG   — отладочная информация
##   LogLevel.INFO    — информационные сообщения
##   LogLevel.WARNING — предупреждения (push_warning)
##   LogLevel.ERROR   — ошибки (push_error)
##
## ── Базовое использование ──
##   LoggerGlobal.debug("Player", "Позиция: %s" % position)
##   LoggerGlobal.info("Player", "Персонаж заспавнен")
##   LoggerGlobal.warning("FireWorm", "Цель потеряна")
##   LoggerGlobal.error("Network", "Соединение разорвано")
##
## ── Фильтрация источников ──
##   LoggerGlobal.mute_source("FSM")       — заглушить источник
##   LoggerGlobal.unmute_source("FSM")      — снять глушение
##   LoggerGlobal.toggle_mute("FSM")        — переключить
##   LoggerGlobal.is_muted("FSM")           — проверить статус
##   LoggerGlobal.get_muted_sources()       — список заглушенных
##
## ── Дедупликация / антиспам ──
##   Если одно и то же сообщение от одного источника повторяется
##   в пределах dedup_window_sec (по умолчанию 2 сек), дубликаты
##   схлопываются. По истечении окна выводится сводка:
##     "↑ Сообщение "..." от [Source] повторилось N раз (схлопнуто)"
##
##   При достижении spam_threshold (по умолчанию 10) повторов
##   выводится предупреждение:
##     "⚠ СПАМ: [Source] повторяет "..." уже 10 раз!"
##
##   LoggerGlobal.flush_all_dedup()         — принудительный сброс
##
## ── Настройки (можно менять в рантайме) ──
##   min_log_level: LogLevel     — минимальный уровень (DEBUG)
##   max_history_size: int       — макс. записей в буфере (500)
##   console_output_enabled: bool — вывод в консоль Godot (true)
##   dedup_enabled: bool         — дедупликация включена (true)
##   dedup_window_sec: float     — окно схлопывания, сек (2.0)
##   spam_threshold: int         — порог спам-предупреждения (10)
##
## ── История и запросы ──
##   LoggerGlobal.get_history()             — полная история
##   LoggerGlobal.get_filtered_history(     — с фильтрацией
##       level_filter, source_filter)
##   LoggerGlobal.get_known_sources()       — все источники
##   LoggerGlobal.clear_history()           — очистить буфер
##
## ── Сигналы (для UI-панели) ──
##   log_added(entry: LogEntry)  — новая запись добавлена
##   log_cleared                 — история очищена

# ─── Перечисление уровней логирования ───

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
}

# ─── Структура одной записи лога ───

class LogEntry:
	var timestamp: String
	var level: LogLevel
	var source: String
	var message: String

	func _init(p_timestamp: String, p_level: LogLevel, p_source: String, p_message: String) -> void:
		timestamp = p_timestamp
		level = p_level
		source = p_source
		message = p_message

# ─── Настройки ───

## Постоянный тег для фильтрации логов в Logcat
const LOGCAT_TAG: String = "iapp_demo"

## Минимальный уровень логирования — сообщения ниже этого уровня игнорируются
var min_log_level: LogLevel = LogLevel.DEBUG

## Максимальное количество хранимых записей в истории
var max_history_size: int = 500

## Включён ли вывод логов в консоль Godot
var console_output_enabled: bool = true

# ─── Фильтрация по источникам ───

## Множество заглушенных (muted) источников — их логи не выводятся
var _muted_sources: Dictionary = {}

# ─── Антиспам / дедупликация ───

## Включена ли система подавления дубликатов
var dedup_enabled: bool = false

## Временное окно дедупликации (секунды) — дубликаты внутри окна схлопываются
var dedup_window_sec: float = 2.0

## Порог повторений, после которого источник считается «спамером»
var spam_threshold: int = 10

## Внутренний трекер дубликатов: ключ = "source::message",
## значение = { "count": int, "level": LogLevel, "first_tick": int, "last_tick": int, "warned": bool }
var _dedup_tracker: Dictionary = {}

# ─── Хранилище логов ───

var _log_history: Array[LogEntry] = []

# ─── Сигналы ───

## Испускается при добавлении новой записи (для UI-панели)
signal log_added(entry: LogEntry)

## Испускается при очистке истории логов
signal log_cleared


# ─── Маппинг уровней для вывода ───

var _level_names: Dictionary = {
	LogLevel.DEBUG: "DEBUG",
	LogLevel.INFO: "INFO",
	LogLevel.WARNING: "WARN",
	LogLevel.ERROR: "ERROR",
}

# var _level_colors: Dictionary = {
#	LogLevel.DEBUG: "gray",
#	LogLevel.INFO: "white",
#	LogLevel.WARNING: "yellow",
#	LogLevel.ERROR: "red",
#}


# Инициализация логгера
func _ready() -> void:
	info("LoggerGlobal", "Логгер инициализирован")
	if OS.is_debug_build():
		info("LoggerGlobal", "Отладочная сборка включена, логгируем все сообщения")
		min_log_level = LogLevel.DEBUG
	else:
		info("LoggerGlobal", "Отладочная сборка отключена, логгируем только ошибки и предупреждения")
		min_log_level = LogLevel.WARNING


# ─── Публичные методы логирования ───


## Записывает сообщение уровня DEBUG
func debug(source: String, message: String) -> void:
	_log(LogLevel.DEBUG, source, message)


## Записывает сообщение уровня INFO
func info(source: String, message: String) -> void:
	_log(LogLevel.INFO, source, message)


## Записывает сообщение уровня WARNING
func warning(source: String, message: String) -> void:
	_log(LogLevel.WARNING, source, message)


## Записывает сообщение уровня ERROR
func error(source: String, message: String) -> void:
	_log(LogLevel.ERROR, source, message)


# ─── Управление фильтрацией ───


## Заглушает источник — его логи перестают выводиться
func mute_source(source: String) -> void:
	_muted_sources[source] = true
	info("LoggerGlobal", "Источник заглушен: %s" % source)


## Снимает глушение с источника
func unmute_source(source: String) -> void:
	_muted_sources.erase(source)
	info("LoggerGlobal", "Источник разглушен: %s" % source)


## Переключает состояние глушения источника
func toggle_mute(source: String) -> void:
	if _muted_sources.has(source):
		unmute_source(source)
	else:
		mute_source(source)


## Возвращает true, если источник заглушен
func is_muted(source: String) -> bool:
	return _muted_sources.has(source)


## Возвращает список всех заглушенных источников
func get_muted_sources() -> Array:
	return _muted_sources.keys()


# ─── Управление историей ───


## Очищает всю историю логов
func clear_history() -> void:
	_log_history.clear()
	log_cleared.emit()
	info("LoggerGlobal", "История логов очищена")


## Возвращает полную историю логов
func get_history() -> Array[LogEntry]:
	return _log_history


## Возвращает отфильтрованную историю по уровню и/или источнику
func get_filtered_history(
	level_filter: LogLevel = LogLevel.DEBUG,
	source_filter: String = ""
) -> Array[LogEntry]:
	var result: Array[LogEntry] = []

	for entry: LogEntry in _log_history:
		# Проверка уровня
		if entry.level < level_filter:
			continue

		# Проверка источника
		if source_filter != "" and entry.source != source_filter:
			continue

		result.append(entry)

	return result


## Возвращает список всех уникальных источников, встречавшихся в логах
func get_known_sources() -> Array[String]:
	var sources: Dictionary = {}

	for entry: LogEntry in _log_history:
		sources[entry.source] = true

	var result: Array[String] = []
	for key: String in sources.keys():
		result.append(key)

	return result


# ─── Внутренняя логика ───


# Основной метод записи лога
func _log(level: LogLevel, source: String, message: String) -> void:
	# Проверка минимального уровня
	if level < min_log_level:
		return

	# Проверка фильтра источников
	if _muted_sources.has(source):
		return

	# Дедупликация
	if dedup_enabled:
		var dedup_key: String = "%s::%s" % [source, message]
		var now_ms: int = Time.get_ticks_msec()

		if _dedup_tracker.has(dedup_key):
			var tracker: Dictionary = _dedup_tracker[dedup_key]
			var elapsed_sec: float = (now_ms - tracker["last_tick"]) / 1000.0

			# Сообщение повторяется внутри временного окна — схлопываем
			if elapsed_sec <= dedup_window_sec:
				tracker["count"] += 1
				tracker["last_tick"] = now_ms

				# Предупреждение о спаме при достижении порога
				if tracker["count"] == spam_threshold and not tracker["warned"]:
					tracker["warned"] = true
					var spam_msg: String = "⚠ СПАМ: [%s] повторяет \"%s\" уже %d раз!" % [
						source, message, tracker["count"]
					]
					_force_log(LogLevel.WARNING, "LoggerGlobal", spam_msg)

				return

			# Окно истекло — сбрасываем трекер и выводим сводку
			_flush_dedup_entry(dedup_key)

		# Регистрируем новое сообщение в трекере
		_dedup_tracker[dedup_key] = {
			"count": 1,
			"level": level,
			"source": source,
			"message": message,
			"first_tick": now_ms,
			"last_tick": now_ms,
			"warned": false,
		}

	# Формирование записи
	var timestamp: String = _get_timestamp()
	var entry: LogEntry = LogEntry.new(timestamp, level, source, message)

	# Сохранение в историю
	_log_history.append(entry)

	# Обрезка истории при превышении лимита
	if _log_history.size() > max_history_size:
		_log_history.pop_front()

	# Вывод в консоль Godot
	if console_output_enabled:
		_print_to_console(entry)

	# Оповещение подписчиков (UI-панель и т.д.)
	log_added.emit(entry)


# Форматирует и выводит запись в консоль Godot
func _print_to_console(entry: LogEntry) -> void:
	var level_name: String = _level_names.get(entry.level, "???")
	var formatted: String = "[%s] [%s] [%s] [%s] %s" % [
		LOGCAT_TAG, entry.timestamp, level_name, entry.source, entry.message
	]

	match entry.level:
		LogLevel.DEBUG:
			print(formatted)
		LogLevel.INFO:
			print(formatted)
		LogLevel.WARNING:
			push_warning(formatted)
		LogLevel.ERROR:
			push_error(formatted)


# Возвращает текущую временную метку в формате ЧЧ:ММ:СС.ммм
func _get_timestamp() -> String:
	var ticks: int = Time.get_ticks_msec()
	var total_seconds: int = int(ticks / 1000.0)
	var ms: int = ticks % 1000
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60

	return "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, ms]


# Периодическая проверка и сброс просроченных дубликатов
func _process(_delta: float) -> void:
	if not dedup_enabled or _dedup_tracker.is_empty():
		return

	var now_ms: int = Time.get_ticks_msec()
	var expired_keys: Array[String] = []

	# Собираем ключи с истёкшим окном
	for key: String in _dedup_tracker:
		var tracker: Dictionary = _dedup_tracker[key]
		var elapsed_sec: float = (now_ms - tracker["last_tick"]) / 1000.0

		if elapsed_sec > dedup_window_sec:
			expired_keys.append(key)

	# Сбрасываем просроченные записи
	for key: String in expired_keys:
		_flush_dedup_entry(key)


# Записывает лог, минуя дедупликацию (для системных сообщений логгера)
func _force_log(level: LogLevel, source: String, message: String) -> void:
	var timestamp: String = _get_timestamp()
	var entry: LogEntry = LogEntry.new(timestamp, level, source, message)

	# Сохранение в историю
	_log_history.append(entry)

	if _log_history.size() > max_history_size:
		_log_history.pop_front()

	# Вывод в консоль
	if console_output_enabled:
		_print_to_console(entry)

	log_added.emit(entry)


# Сбрасывает трекер дубликатов для конкретного ключа и выводит сводку
func _flush_dedup_entry(key: String) -> void:
	if not _dedup_tracker.has(key):
		return

	var tracker: Dictionary = _dedup_tracker[key]
	var count: int = tracker["count"]

	# Если было больше одного повторения — выводим сводку
	if count > 1:
		var summary_msg: String = "↑ Сообщение \"%s\" от [%s] повторилось %d раз (схлопнуто)" % [
			tracker["message"], tracker["source"], count
		]
		_force_log(tracker["level"], tracker["source"], summary_msg)

	_dedup_tracker.erase(key)


## Принудительно сбрасывает все накопленные дубликаты и выводит сводки
func flush_all_dedup() -> void:
	var keys: Array = _dedup_tracker.keys().duplicate()

	for key: String in keys:
		_flush_dedup_entry(key)
