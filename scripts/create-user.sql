CREATE USER 'ragnarok'@'localhost' IDENTIFIED BY 'ragnarok';

CREATE DATABASE ragnarok;
GRANT ALL ON ragnarok.* TO 'ragnarok'@'localhost' IDENTIFIED BY 'ragnarok';

FLUSH PRIVILEGES;