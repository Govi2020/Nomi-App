use serde::Serialize;
use tauri::Manager;

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct BackendInfo {
    base_url: String,
    status: &'static str,
}

#[tauri::command]
fn get_backend_info() -> BackendInfo {
    let external = std::env::var("NOMI_EXTERNAL_BACKEND").ok();
    BackendInfo {
        base_url: external.unwrap_or_default(),
        status: if std::env::var_os("NOMI_EXTERNAL_BACKEND").is_some() { "ready" } else { "starting" },
    }
}

#[tauri::command]
fn restart_backend() -> Result<(), String> {
    Err("The managed backend lifecycle is not available in this build yet.".into())
}

#[tauri::command]
fn open_logs_folder(app: tauri::AppHandle) -> Result<(), String> {
    let path = app.path().app_log_dir().map_err(|error| error.to_string())?;
    std::fs::create_dir_all(&path).map_err(|error| error.to_string())?;
    tauri_plugin_opener::OpenerExt::opener(&app)
        .open_path(path.to_string_lossy(), None::<&str>)
        .map_err(|error| error.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_focus();
            }
        }))
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![get_backend_info, restart_backend, open_logs_folder])
        .run(tauri::generate_context!())
        .expect("error while running Nomi desktop application");
}
