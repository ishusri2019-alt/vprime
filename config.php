<?php
// Copy values to suit your InterServer account. Keep this file outside public_html if possible.
define('DB_HOST', 'localhost');
define('DB_NAME', 'your_db_name');
define('DB_USER', 'your_db_user');
define('DB_PASS', 'your_db_password');

define('BASE_URL', 'https://yourdomain.com/vprime');   // no trailing slash
define('APP_NAME', 'VPrime Health Care');
define('APP_TIMEZONE', 'Asia/Kolkata');
define('SESSION_NAME', 'vprime_sess');

// Long random string, used to hash session IDs before storing. Change it once, then never again.
define('APP_SECRET', 'CHANGE_ME_TO_A_LONG_RANDOM_STRING');
define('APP_DEBUG', false);
