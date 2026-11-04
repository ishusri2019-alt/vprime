<?php
declare(strict_types=1);
require_once __DIR__ . '/../config/config.php';

date_default_timezone_set(APP_TIMEZONE);
error_reporting(APP_DEBUG ? E_ALL : 0);
ini_set('display_errors', APP_DEBUG ? '1' : '0');

$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
session_name(SESSION_NAME);
session_set_cookie_params([
    'lifetime' => 0, 'path' => '/', 'secure' => $isHttps,
    'httponly' => true, 'samesite' => 'Lax',
]);
ini_set('session.use_strict_mode', '1');
session_start();

header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER, DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
             PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
             PDO::ATTR_EMULATE_PREPARES => false]
        );
        $pdo->exec("SET time_zone = '+05:30'");
    }
    return $pdo;
}

function e(?string $v): string { return htmlspecialchars((string)$v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }

function setting(string $key, $default = null) {
    static $all = null;
    if ($all === null) {
        $all = db()->query('SELECT setting_key, setting_value FROM system_settings')->fetchAll(PDO::FETCH_KEY_PAIR);
    }
    return $all[$key] ?? $default;
}

function csrf_token(): string {
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(32));
    return $_SESSION['csrf'];
}
function csrf_field(): string { return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">'; }
function csrf_check(): void {
    $sent = $_POST['csrf'] ?? '';
    if (!is_string($sent) || !hash_equals($_SESSION['csrf'] ?? '', $sent)) {
        http_response_code(419);
        exit('Session expired or invalid request. Please go back, refresh and try again.');
    }
}

function client_ip(): string {
    // REMOTE_ADDR only: forwarded headers are spoofable and we do not try to see through VPNs.
    return substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 45);
}
function device_category(string $ua): string {
    if ($ua === '') return 'unknown';
    if (preg_match('/ipad|tablet|kindle|silk|(android(?!.*mobile))/i', $ua)) return 'tablet';
    if (preg_match('/mobile|iphone|ipod|android|blackberry|opera mini|iemobile/i', $ua)) return 'mobile';
    return 'desktop';
}
function session_fingerprint(): string { return hash_hmac('sha256', session_id(), APP_SECRET); }

function redirect(string $path): never { header('Location: ' . BASE_URL . '/' . ltrim($path, '/')); exit; }
