class_name MonWorldContentProvider
extends Node

signal pack_loaded(pack: MonWorldContentPack)
signal pack_failed(message: String)

var dialog: FileDialog
var _web_callback: Variant

func choose(parent: Node) -> void:
	if OS.has_feature("web"):
		_choose_web()
		return
	if is_instance_valid(dialog):
		dialog.popup_centered_ratio(0.7)
		return
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.monpack ; MonWorld content packs"])
	dialog.title = "Select a MonWorld content pack"
	dialog.file_selected.connect(_on_file_selected)
	parent.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	var result := MonWorldContentPack.from_path(path)
	if result.ok:
		pack_loaded.emit(result.pack)
	else:
		pack_failed.emit(str(result.error))

func _choose_web() -> void:
	_web_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window := JavaScriptBridge.get_interface("window")
	window.monworld_pack_callback = _web_callback
	JavaScriptBridge.eval("""
(function() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = '.monpack,application/zip';
  input.onchange = function() {
    const file = input.files && input.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function() {
      const bytes = new Uint8Array(reader.result);
      let binary = '';
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
      window.monworld_pack_callback(btoa(binary));
    };
    reader.onerror = function() { window.monworld_pack_callback(''); };
    reader.readAsArrayBuffer(file);
  };
  input.click();
})();
""")

func _on_web_file(args: Array) -> void:
	if args.is_empty() or str(args[0]).is_empty():
		pack_failed.emit("no content pack was selected")
		return
	var data := Marshalls.base64_to_raw(str(args[0]))
	var path := "user://monworld-session.monpack"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		pack_failed.emit("could not store the selected content pack locally")
		return
	file.store_buffer(data)
	file.close()
	_on_file_selected(path)
