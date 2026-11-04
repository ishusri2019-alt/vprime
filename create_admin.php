<?php
// ONE-TIME SETUP. Visit once, create the Super Admin, then DELETE this file (it tries to delete itself).
require_once __DIR__ . '/../includes/auth.php';

$exists = (int)db()->query("SELECT COUNT(*) FROM admin_users")->fetchColumn();
if ($exists > 0) { @unlink(__FILE__); exit('Setup already completed. This file has been removed.'); }

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $name = trim($_POST['name'] ?? ''); $email = strtolower(trim($_POST['email'] ?? '')); $pw = $_POST['password'] ?? '';
    if ($name === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) $msg = 'Enter a valid name and email.';
    elseif ($err = password_policy_error($pw)) $msg = $err;
    else {
        db()->prepare("INSERT INTO admin_users (name,email,password_hash,role) VALUES (?,?,?,'super_admin')")
            ->execute([$name, $email, password_hash($pw, PASSWORD_DEFAULT)]);
        @unlink(__FILE__);
        exit('Super Admin created. Setup file removed. <a href="../admin/login.php">Go to login</a>');
    }
}
?>
<!doctype html><html><head><meta charset="utf-8"><title>VPrime setup</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet"></head>
<body class="bg-light"><div class="container" style="max-width:420px;margin-top:60px">
<h4>Create Super Admin</h4><?php if ($msg): ?><div class="alert alert-danger"><?= e($msg) ?></div><?php endif; ?>
<form method="post"><?= csrf_field() ?>
<input class="form-control mb-2" name="name" placeholder="Full name" required>
<input class="form-control mb-2" type="email" name="email" placeholder="Email" required>
<input class="form-control mb-3" type="password" name="password" placeholder="Password (10+ chars)" required>
<button class="btn btn-primary w-100">Create</button></form></div></body></html>
