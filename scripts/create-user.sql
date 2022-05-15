CREATE USER '{0}'@'localhost' IDENTIFIED BY '{1}';

CREATE DATABASE ragnarok;
GRANT ALL ON ragnarok.* TO '{0}'@'localhost' IDENTIFIED BY '{1}';

--CREATE DATABASE ragnarok_log;
--GRANT ALL ON ragnarok_log.* TO '{0}'@'localhost' IDENTIFIED BY '{1}';

FLUSH PRIVILEGES;