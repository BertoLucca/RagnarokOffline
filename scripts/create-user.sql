CREATE USER '{0}'@'localhost' IDENTIFIED BY '{1}';

CREATE DATABASE rAthena;
GRANT ALL ON rAthena.* TO '{0}'@'localhost' IDENTIFIED BY '{1}';
FLUSH PRIVILEGES;

CREATE DATABASE rAthena_log;
GRANT ALL ON rAthena_log.* TO '{0}'@'localhost' IDENTIFIED BY '{1}';
FLUSH PRIVILEGES;
