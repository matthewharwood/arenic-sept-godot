class_name ArenicBrowserSaveBackend
extends ArenicSaveBackend
## IndexedDB commits before reporting success; no filesystem or memory fallback.
const TIMEOUT_MSEC: int = 15000
const BRIDGE_SOURCE: String = """
(() => {
  if (window.ArenicIndexedSaveStore) return;
  const limit = 64 * 1024 * 1024;
  const encoder = new TextEncoder();
  const revisionOf = async (record) => {
    if (record === undefined) return 0;
    if (typeof record !== 'string' || encoder.encode(record).length > limit) return -1;
    try {
      const value = JSON.parse(record);
      if (!value || Array.isArray(value) || !Number.isInteger(value.revision) ||
          value.revision < 1 || value.revision > 2147483647) return -1;
      if ('payload_json' in value || 'checksum' in value) {
        if (typeof value.payload_json !== 'string' || typeof value.checksum !== 'string') return -1;
        const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value.payload_json));
        const checksum = Array.from(new Uint8Array(digest), v => v.toString(16).padStart(2, '0')).join('');
        if (checksum !== value.checksum) return -1;
      }
      return value.revision;
    } catch (_) { return -1; }
  };
  window.ArenicIndexedSaveStore = {
    run: async function (id, name, operation, slot, expected, record, expectedRunId, callback) {
      let database = null;
      let transaction = null;
      let finished = false;
      let timeout = null;
      const finish = result => {
        if (finished) return;
        finished = true;
        clearTimeout(timeout);
        if (database) database.close();
        callback(id, JSON.stringify(result));
      };
      timeout = setTimeout(() => {
        if (transaction) { try { transaction.abort(); } catch (_) {} }
        finish({ok:false,error:'Browser save storage timed out. Close other Arenic tabs and retry.'});
      }, 14000);
      try {
        if (!window.indexedDB) throw new Error('IndexedDB is unavailable. Enable browser site storage.');
        if (!window.crypto || !crypto.subtle) throw new Error('Save integrity checks require HTTPS or localhost.');
        database = await new Promise((resolve, reject) => {
          const request = indexedDB.open(name, 1);
          request.onupgradeneeded = () => {
            if (!request.result.objectStoreNames.contains('slots')) request.result.createObjectStore('slots');
          };
          request.onsuccess = () => {
            if (finished) { request.result.close(); return; }
            request.result.onversionchange = () => request.result.close();
            resolve(request.result);
          };
          request.onerror = () => reject(request.error || new Error('Cannot open browser save storage.'));
          request.onblocked = () => reject(new Error('Browser save storage is blocked. Close other Arenic tabs and retry.'));
        });
        if (finished) return;
        if (operation === 'read') {
          const records = {};
          await new Promise((resolve, reject) => {
            transaction = database.transaction('slots', 'readonly');
            const store = transaction.objectStore('slots');
            for (let index = 0; index < 8; index++) {
              const request = store.get(index);
              request.onsuccess = () => {
                if (request.result === undefined) return;
                // Keep damaged records visible and deletable without allocating unbounded data.
                records[String(index)] = typeof request.result === 'string' &&
                  encoder.encode(request.result).length <= limit ? request.result : '{invalid-or-oversized-save';
              };
            }
            transaction.oncomplete = resolve;
            transaction.onabort = () => reject(transaction.error || new Error('Browser save read was aborted.'));
            transaction.onerror = () => {};
          });
          finish({ok:true,records,error:''});
          return;
        }
        // Hash validation is asynchronous. Do it outside the write transaction,
        // then compare the exact record again inside the atomic transaction.
        let previous;
        await new Promise((resolve, reject) => {
          transaction = database.transaction('slots', 'readonly');
          const request = transaction.objectStore('slots').get(slot);
          request.onsuccess = () => { previous = request.result; };
          transaction.oncomplete = resolve;
          transaction.onabort = () => reject(transaction.error || new Error('Browser save read was aborted.'));
          transaction.onerror = () => {};
        });
        const revision = await revisionOf(previous);
        if (finished) return;
        if (revision !== expected) {
          finish({ok:false,error:'This slot changed in another game. Reload it before saving or deleting; your progress remains in memory.'});
          return;
        }
        const identityOf = value => {
          try { const id = JSON.parse(value).run_id; return typeof id === 'string' ? id : ''; }
          catch (_) { return ''; }
        };
        if ((operation === 'write' && expected > 0 && identityOf(previous) !== identityOf(record)) ||
            (operation === 'delete' && identityOf(previous) !== expectedRunId)) {
          finish({ok:false,error:'This slot now belongs to a different game. Reload the slot list; your progress remains in memory.'});
          return;
        }
        let conflict = false;
        await new Promise((resolve, reject) => {
          transaction = database.transaction('slots', 'readwrite');
          const store = transaction.objectStore('slots');
          const request = store.get(slot);
          request.onsuccess = () => {
            const bothMalformedTypes = expected === -1 && request.result !== undefined && previous !== undefined &&
              typeof request.result !== 'string' && typeof previous !== 'string';
            if (request.result !== previous && !bothMalformedTypes) { conflict = true; transaction.abort(); return; }
            if (operation === 'write') store.put(record, slot);
            else store.delete(slot);
          };
          transaction.oncomplete = resolve;
          transaction.onabort = () => reject(conflict ? new Error('This slot changed in another tab. Reload it before saving or deleting.') :
            transaction.error || new Error('Browser save transaction was aborted. The previous save is unchanged.'));
          transaction.onerror = () => {};
        });
        finish({ok:true,error:''});
      } catch (error) {
        const detail = error && error.name === 'QuotaExceededError' ?
          'Browser storage is full. Free site storage space and retry; the previous save is unchanged.' :
          'Cannot use browser save storage: ' + (error && error.message ? error.message : String(error));
        finish({ok:false,error:detail});
      }
    }
  };
})();
"""
var database_name: String
var _bridge: JavaScriptObject
var _callback: JavaScriptObject
var _busy: bool = false
var _request_id: int = 0
var _response: Dictionary = {}


func _init(name: String = "arenic-saves") -> void:
	database_name = name


func read_all() -> Dictionary:
	return await _request("read", 0, 0, "")


func write_record(slot: int, expected_revision: int, record: String) -> Dictionary:
	var invalid := write_error(slot, expected_revision, record)
	if not invalid.is_empty():
		return failure(invalid)
	return await _request("write", slot, expected_revision, record)


func delete_record(slot: int, expected_revision: int, expected_run_id: String = "") -> Dictionary:
	var invalid := delete_error(slot, expected_revision)
	if not invalid.is_empty():
		return failure(invalid)
	return await _request("delete", slot, expected_revision, "", expected_run_id)


func _request(operation: String, slot: int, expected_revision: int, record: String, expected_run_id: String = "") -> Dictionary:
	if not OS.has_feature("web"):
		return failure("IndexedDB saves are available only in a browser export.")
	if _busy:
		return failure("A browser save operation is already in progress. Retry after it completes.")
	if database_name.is_empty() or database_name.length() > 100:
		return failure("The browser save database name is invalid.")
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return failure("Browser saves require the running game loop.")
	if _bridge == null:
		JavaScriptBridge.eval(BRIDGE_SOURCE, true)
		_bridge = JavaScriptBridge.get_interface("ArenicIndexedSaveStore")
		_callback = JavaScriptBridge.create_callback(_on_response)
	if _bridge == null or _callback == null:
		return failure("The browser JavaScript bridge is unavailable. Use an official Web export template.")
	_busy = true
	_request_id += 1
	_response = {}
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	_bridge.run(_request_id, database_name, operation, slot, expected_revision, record, expected_run_id, _callback)
	while _response.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	_busy = false
	if _response.is_empty():
		return failure("The browser did not acknowledge save storage. Reload before retrying to avoid an uncertain write.")
	return _response


func _on_response(arguments: Array) -> void:
	if arguments.size() != 2 or int(arguments[0]) != _request_id or not _busy:
		return
	var parser := JSON.new()
	if parser.parse(str(arguments[1])) == OK and parser.data is Dictionary:
		_response = parser.data
	else:
		_response = failure("The browser returned an invalid save storage response.")
