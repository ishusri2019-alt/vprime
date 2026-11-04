<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

const ROLE_SUPER = 'super_admin';
const ROLE_BRANCH = 'branch_admin';
const ROLE_COMPLIANCE = 'compliance_executive';

function log_activity(string $action, string $details = '', ?int $adminId = null): void {
    $adminId ??= $_SESSION['admin_id'] ?? null;
    db()->prepare('INSERT INTO admin_activity_logs (admin_id, action, details, ip_address) VALUES (?,?,?,?)')
        ->execute([$adminId, $action, mb_substr($details, 0, 500), client_ip()]);
}

/** Returns null on success, or an error message. Generic message avoids revealing which part failed. */
function admin_login(string $email, string $password): ?string {
    $generic = 'Invalid email or password.';
    $st = db()->prepare('SELECT * FROM admin_users WHERE email = ? AND is_active = 1');
    $st->execute([strtolower(trim($email))]);
    $u = $st->fetch();
    if (!$u) { password_hash($password, PASSWORD_DEFAULT); return $generic; }  // equalise timing

    if ($u['locked_until'] && strtotime($u['locked_until']) > time()) {
        return 'Account temporarily locked. Please try again later.';
    }
    if (!password_verify($password, $u['password_hash'])) {
        $fails = (int)$u['failed_attempts'] + 1;
        $lock = null;
        if ($fails >= (int)setting('max_login_attempts', 5)) {
            $lock = date('Y-m-d H:i:s', time() + 60 * (int)setting('lockout_minutes', 15));
            $fails = 0;
        }
        db()->prepare('UPDATE admin_users SET failed_attempts=?, locked_until=? WHERE id=?')->execute([$fails, $lock, $u['id']]);
        log_activity('login_failed', 'email=' . $email, (int)$u['id']);
        return $generic;
    }
    if (password_needs_rehash($u['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare('UPDATE admin_users SET password_hash=? WHERE id=?')->execute([password_hash($password, PASSWORD_DEFAULT), $u['id']]);
    }
    session_regenerate_id(true);
    $_SESSION['admin_id'] = (int)$u['id'];
    $_SESSION['admin_name'] = $u['name'];
    $_SESSION['admin_role'] = $u['role'];
    $_SESSION['admin_branch'] = $u['branch_id'] !== null ? (int)$u['branch_id'] : null;
    $_SESSION['last_activity'] = time();
    db()->prepare('UPDATE admin_users SET failed_attempts=0, locked_until=NULL, last_login_at=NOW() WHERE id=?')->execute([$u['id']]);
    log_activity('login', '', (int)$u['id']);
    return null;
}

function admin_logout(): void {
    if (!empty($_SESSION['admin_id'])) log_activity('logout');
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 3600, $p['path'], $p['domain'] ?? '', $p['secure'], $p['httponly']);
    }
    session_destroy();
}

function require_login(array $roles = []): void {
    $timeout = 60 * (int)setting('session_timeout_minutes', 20);
    if (empty($_SESSION['admin_id']) || (time() - ($_SESSION['last_activity'] ?? 0)) > $timeout) {
        $expired = !empty($_SESSION['admin_id']);
        if ($expired) admin_logout();
        redirect('admin/login.php' . ($expired ? '?timeout=1' : ''));
    }
    $_SESSION['last_activity'] = time();
    if ($roles && !in_array($_SESSION['admin_role'], $roles, true)) {
        http_response_code(403);
        exit('You do not have permission to view this page.');
    }
}

/** null = all branches (Super Admin, Compliance Executive); int = restricted to that branch (Branch Admin). */
function branch_scope(): ?int {
    return ($_SESSION['admin_role'] ?? '') === ROLE_BRANCH ? (int)$_SESSION['admin_branch'] : null;
}

/** Appends a branch restriction to a WHERE clause: [$sql, $params] = scope_sql('f.branch_id', $sql, $params); */
function scope_sql(string $column, string $sql, array $params): array {
    $b = branch_scope();
    if ($b !== null) { $sql .= " AND $column = ?"; $params[] = $b; }
    return [$sql, $params];
}

function password_policy_error(string $pw): ?string {
    if (strlen($pw) < 10) return 'Password must be at least 10 characters.';
    if (!preg_match('/[A-Z]/', $pw) || !preg_match('/[a-z]/', $pw) || !preg_match('/\d/', $pw)) {
        return 'Password must include upper-case, lower-case and a number.';
    }
    return null;
}
