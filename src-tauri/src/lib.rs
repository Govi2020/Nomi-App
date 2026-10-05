use serde::{Deserialize, Serialize};
use std::{
    collections::VecDeque,
    fs::{self, File, OpenOptions},
    io::{Read, Seek, SeekFrom, Write},
    net::{Ipv4Addr, SocketAddrV4, TcpListener, TcpStream},
    path::{Path, PathBuf},
    process::{Child, ChildStdin, Command, ExitStatus, Stdio},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex, MutexGuard,
    },
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tauri::{AppHandle, Emitter, Manager, RunEvent, State};

const STARTUP_TIMEOUT: Duration = Duration::from_secs(60);
const POLL_INTERVAL: Duration = Duration::from_millis(200);
const RESTART_WINDOW: Duration = Duration::from_secs(120);
const MAX_RESTARTS: usize = 3;
const MAX_STDIO_LOG_BYTES: u64 = 5 * 1024 * 1024;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BackendInfo {
    base_url: String,
    status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    log_path: Option<String>,
}

impl BackendInfo {
    fn new(base_url: String, status: &str, error: Option<String>, log_path: Option<String>) -> Self {
        Self {
            base_url,
            status: status.to_owned(),
            error,
            log_path,
        }
    }
}

struct ManagedBackend {
    child: Option<Child>,
    stdin: Option<ChildStdin>,
}

struct BackendManager {
    info: Mutex<BackendInfo>,
    child: Mutex<ManagedBackend>,
    generation: AtomicU64,
    stopping: AtomicBool,
}

impl Default for BackendManager {
    fn default() -> Self {
        Self {
            info: Mutex::new(BackendInfo::new(String::new(), "starting", None, None)),
            child: Mutex::new(ManagedBackend { child: None, stdin: None }),
            generation: AtomicU64::new(1),
            stopping: AtomicBool::new(false),
        }
    }
}

impl BackendManager {
    fn info(&self) -> BackendInfo {
        lock(&self.info).clone()
    }

    fn set_info(&self, next: BackendInfo) {
        *lock(&self.info) = next;
    }

    fn stop(&self) {
        self.stopping.store(true, Ordering::SeqCst);
        self.generation.fetch_add(1, Ordering::SeqCst);
        stop_child(self);
        self.set_info(BackendInfo::new(String::new(), "stopped", None, None));
    }
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[tauri::command]
fn get_backend_info(manager: State<'_, Arc<BackendManager>>) -> BackendInfo {
    manager.info()
}

#[tauri::command]
fn restart_backend(app: AppHandle, manager: State<'_, Arc<BackendManager>>) -> Result<(), String> {
    if std::env::var_os("NOMI_EXTERNAL_BACKEND").is_some() {
        return Err("Restart is unavailable while NOMI_EXTERNAL_BACKEND is set.".into());
    }
    manager.stopping.store(false, Ordering::SeqCst);
    let generation = manager.generation.fetch_add(1, Ordering::SeqCst) + 1;
    stop_child(&manager);
    let manager = manager.inner().clone();
    set_and_emit(
        &app,
        &manager,
        "backend://starting",
        BackendInfo::new(String::new(), "starting", None, None),
    );
    launch_manager(app, manager, generation)
}

#[tauri::command]
fn open_logs_folder(app: tauri::AppHandle) -> Result<(), String> {
    let path = app.path().app_log_dir().map_err(|error| error.to_string())?;
    std::fs::create_dir_all(&path).map_err(|error| error.to_string())?;
    tauri_plugin_opener::OpenerExt::opener(&app)
        .open_path(path.to_string_lossy(), None::<&str>)
        .map_err(|error| error.to_string())
}

fn launch_manager(
    app: AppHandle,
    manager: Arc<BackendManager>,
    generation: u64,
) -> Result<(), String> {
    thread::Builder::new()
        .name("nomi-backend-manager".into())
        .spawn(move || manage_backend(app, manager, generation))
        .map(|_| ())
        .map_err(|error| format!("Could not start the backend manager: {error}"))
}

fn manage_backend(app: AppHandle, manager: Arc<BackendManager>, generation: u64) {
    if manager.stopping.load(Ordering::SeqCst) || generation != manager.generation.load(Ordering::SeqCst) {
        return;
    }

    if let Ok(base_url) = std::env::var("NOMI_EXTERNAL_BACKEND") {
        set_and_emit(
            &app,
            &manager,
            "backend://ready",
            BackendInfo::new(base_url, "ready", None, None),
        );
        return;
    }

    let mut restart_times = VecDeque::<Instant>::new();
    let mut preferred_port = None;
    let mut startup_retries = 0;
    loop {
        if manager.stopping.load(Ordering::SeqCst) || generation != manager.generation.load(Ordering::SeqCst) {
            return;
        }
        set_and_emit(
            &app,
            &manager,
            "backend://starting",
            BackendInfo::new(String::new(), "starting", None, None),
        );

        let log_path = match app.path().app_log_dir() {
            Ok(path) => path.join("backend-stdio.log"),
            Err(error) => {
                fail(&app, &manager, format!("Could not locate the application log directory: {error}"), None);
                return;
            }
        };
        let mut child = None;
        let mut spawn_error = String::new();
        for _ in 0..5 {
            let port = if let Some(port) = preferred_port {
                port
            } else {
                match pick_loopback_port() {
                    Ok(port) => port,
                    Err(error) => {
                        spawn_error = error;
                        continue;
                    }
                }
            };
            match spawn_backend(&app, port, &log_path) {
                Ok((process, stdin, instance)) => {
                    *lock(&manager.child) = ManagedBackend { child: Some(process), stdin: Some(stdin) };
                    child = Some((port, instance));
                    break;
                }
                Err(error) => spawn_error = error,
            }
            preferred_port = None;
        }
        let Some((port, instance)) = child else {
            fail(&app, &manager, spawn_error, Some(log_path));
            return;
        };
        preferred_port = Some(port);
        let base_url = format!("http://127.0.0.1:{port}");

        let deadline = Instant::now() + STARTUP_TIMEOUT;
        let mut startup_error = None;
        let mut exited_during_startup = false;
        loop {
            if manager.stopping.load(Ordering::SeqCst) || generation != manager.generation.load(Ordering::SeqCst) {
                stop_child(&manager);
                return;
            }
            if let Some(status) = child_exit_status(&manager) {
                startup_error = Some(format!("The backend exited during startup ({status})."));
                exited_during_startup = true;
                clear_child(&manager);
                break;
            }
            if health_ready(port, &instance) {
                set_and_emit(
                    &app,
                    &manager,
                    "backend://ready",
                    BackendInfo::new(base_url.clone(), "ready", None, Some(log_path.display().to_string())),
                );
                break;
            }
            if Instant::now() >= deadline {
                startup_error = Some(format!("The backend did not become ready within {} seconds.", STARTUP_TIMEOUT.as_secs()));
                stop_child(&manager);
                break;
            }
            thread::sleep(POLL_INTERVAL);
        }

        if let Some(error) = startup_error {
            if exited_during_startup && startup_retries < 4 {
                startup_retries += 1;
                preferred_port = None;
                continue;
            }
            fail(&app, &manager, error, Some(log_path.clone()));
            return;
        }

        loop {
            if manager.stopping.load(Ordering::SeqCst) || generation != manager.generation.load(Ordering::SeqCst) {
                return;
            }
            if let Some(status) = child_exit_status(&manager) {
                clear_child(&manager);
                let error = format!("The backend stopped unexpectedly ({status}). Restarting…");
                set_and_emit(
                    &app,
                    &manager,
                    "backend://crashed",
                    BackendInfo::new(base_url.clone(), "crashed", Some(error), Some(log_path.display().to_string())),
                );
                break;
            }
            thread::sleep(POLL_INTERVAL);
        }

        let now = Instant::now();
        while restart_times.front().is_some_and(|when| now.duration_since(*when) >= RESTART_WINDOW) {
            restart_times.pop_front();
        }
        if restart_times.len() >= MAX_RESTARTS {
            fail(
                &app,
                &manager,
                "The backend crashed repeatedly. Use Retry to start it again.".into(),
                Some(log_path),
            );
            return;
        }
        let backoff = Duration::from_secs(1_u64 << restart_times.len());
        restart_times.push_back(now);
        thread::sleep(backoff);
    }
}

fn set_and_emit(app: &AppHandle, manager: &BackendManager, event: &str, info: BackendInfo) {
    manager.set_info(info.clone());
    let _ = app.emit(event, info);
}

fn fail(app: &AppHandle, manager: &BackendManager, message: String, log_path: Option<PathBuf>) {
    set_and_emit(
        app,
        manager,
        "backend://error",
        BackendInfo::new(String::new(), "error", Some(message), log_path.map(|path| path.display().to_string())),
    );
}

fn pick_loopback_port() -> Result<u16, String> {
    TcpListener::bind(SocketAddrV4::new(Ipv4Addr::LOCALHOST, 0))
        .and_then(|listener| listener.local_addr())
        .map(|address| address.port())
        .map_err(|error| format!("Could not allocate a loopback port: {error}"))
}

fn app_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").canonicalize().unwrap_or_else(|_| {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
    })
}

fn spawn_backend(app: &AppHandle, port: u16, log_path: &Path) -> Result<(Child, ChildStdin, String), String> {
    if !cfg!(debug_assertions) {
        return Err("The packaged backend sidecar has not been configured yet.".into());
    }
    let root = app_root();
    let python = if let Some(explicit) = std::env::var_os("NOMI_PYTHON") {
        PathBuf::from(explicit)
    } else if cfg!(windows) {
        root.join(".venv/Scripts/python.exe")
    } else {
        root.join(".venv/bin/python")
    };
    if !python.is_file() {
        return Err(format!(
            "Python environment not found at {}. Create the project .venv or set NOMI_PYTHON.",
            python.display()
        ));
    }

    let data_dir = if cfg!(debug_assertions) {
        std::env::var_os("NOMI_DATA_DIR").map(PathBuf::from)
    } else {
        None
    }
    .map(Ok)
    .unwrap_or_else(|| app.path().app_local_data_dir().map_err(|error| error.to_string()))?;
    fs::create_dir_all(&data_dir).map_err(|error| format!("Could not create app data directory: {error}"))?;
    if let Some(parent) = log_path.parent() {
        fs::create_dir_all(parent).map_err(|error| format!("Could not create app log directory: {error}"))?;
    }
    rotate_backend_log(log_path).map_err(|error| format!("Could not prepare backend log: {error}"))?;
    let output_log = OpenOptions::new().create(true).append(true).open(log_path)
        .map_err(|error| format!("Could not open backend log: {error}"))?;
    let output_log = Arc::new(Mutex::new(output_log));
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_nanos();
    let instance = format!("{}-{stamp}", std::process::id());
    let mut command = Command::new(&python);
    command
        .arg(root.join("backend/entry.py"))
        .arg("--host")
        .arg("127.0.0.1")
        .arg("--port")
        .arg(port.to_string())
        .current_dir(&root)
        .env("NOMI_HOST", "127.0.0.1")
        .env("NOMI_PORT", port.to_string())
        .env("NOMI_DATA_DIR", data_dir)
        .env("NOMI_INSTANCE_ID", &instance)
        .env("NOMI_APP_VERSION", app.package_info().version.to_string())
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if cfg!(debug_assertions) {
        command.env("NOMI_DEV", "1");
    }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x0800_0000);
    }
    let mut child = command.spawn().map_err(|error| format!("Could not start backend at {}: {error}", python.display()))?;
    let stdin = child.stdin.take().ok_or_else(|| "Could not open the backend shutdown pipe.".to_owned())?;
    if let Some(stdout) = child.stdout.take() {
        pipe_output(stdout, output_log.clone(), "stdout");
    }
    if let Some(stderr) = child.stderr.take() {
        pipe_output(stderr, output_log, "stderr");
    }
    Ok((child, stdin, instance))
}

fn pipe_output<R: Read + Send + 'static>(mut source: R, destination: Arc<Mutex<File>>, label: &'static str) {
    let _ = thread::Builder::new().name(format!("nomi-backend-{label}")).spawn(move || {
        let mut buffer = [0_u8; 8192];
        loop {
            let count = match source.read(&mut buffer) {
                Ok(0) | Err(_) => return,
                Ok(count) => count,
            };
            let mut file = lock(&destination);
            let current_size = file.metadata().map(|metadata| metadata.len()).unwrap_or(0);
            if current_size.saturating_add(count as u64) > MAX_STDIO_LOG_BYTES
                && (file.set_len(0).is_err() || file.seek(SeekFrom::Start(0)).is_err())
            {
                return;
            }
            if file.write_all(&buffer[..count]).is_err() {
                return;
            }
        }
    });
}

fn rotate_backend_log(path: &Path) -> std::io::Result<()> {
    if path.metadata().map(|metadata| metadata.len() > MAX_STDIO_LOG_BYTES).unwrap_or(false) {
        File::create(path)?;
    }
    Ok(())
}

fn child_exit_status(manager: &BackendManager) -> Option<ExitStatus> {
    let mut managed = lock(&manager.child);
    managed.child.as_mut().and_then(|child| child.try_wait().ok().flatten())
}

fn clear_child(manager: &BackendManager) {
    let mut managed = lock(&manager.child);
    managed.stdin.take();
    managed.child.take();
}

fn stop_child(manager: &BackendManager) {
    let mut managed = lock(&manager.child);
    if let Some(mut input) = managed.stdin.take() {
        let _ = input.write_all(b"SHUTDOWN\n");
        let _ = input.flush();
    }
    if let Some(mut child) = managed.child.take() {
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match child.try_wait() {
                Ok(Some(_)) => break,
                Ok(None) if Instant::now() < deadline => thread::sleep(Duration::from_millis(50)),
                _ => {
                    let _ = child.kill();
                    let _ = child.wait();
                    break;
                }
            }
        }
    }
}

fn health_ready(port: u16, expected_instance: &str) -> bool {
    let address = SocketAddrV4::new(Ipv4Addr::LOCALHOST, port);
    let Ok(mut stream) = TcpStream::connect_timeout(&address.into(), Duration::from_millis(150)) else {
        return false;
    };
    let _ = stream.set_read_timeout(Some(Duration::from_millis(400)));
    let request = b"GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
    if stream.write_all(request).is_err() {
        return false;
    }
    let mut response = Vec::new();
    if stream.read_to_end(&mut response).is_err() {
        return false;
    }
    let Some(body_start) = response.windows(4).position(|window| window == b"\r\n\r\n") else {
        return false;
    };
    if !response.starts_with(b"HTTP/1.1 200") && !response.starts_with(b"HTTP/1.0 200") {
        return false;
    }
    let Ok(payload) = serde_json::from_slice::<serde_json::Value>(&response[body_start + 4..]) else {
        return false;
    };
    payload.get("status").and_then(|value| value.as_str()) == Some("ok")
        && payload.get("instance").and_then(|value| value.as_str()) == Some(expected_instance)
}

fn start_backend(app: AppHandle, manager: Arc<BackendManager>) {
    let generation = manager.generation.load(Ordering::SeqCst);
    if let Err(error) = launch_manager(app.clone(), manager.clone(), generation) {
        fail(&app, &manager, error, None);
    }
}

fn on_exit(manager: &BackendManager) {
    manager.stop();
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let manager = Arc::new(BackendManager::default());
    let app = tauri::Builder::default()
        .manage(manager)
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_focus();
            }
        }))
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![get_backend_info, restart_backend, open_logs_folder])
        .setup(|app| {
            let manager = app.state::<Arc<BackendManager>>().inner().clone();
            start_backend(app.handle().clone(), manager);
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building Nomi desktop application");

    app.run(|app, event| match event {
        RunEvent::ExitRequested { .. } | RunEvent::Exit => {
            if let Some(manager) = app.try_state::<Arc<BackendManager>>() {
                on_exit(manager.inner());
            }
        }
        _ => {}
    });
}
