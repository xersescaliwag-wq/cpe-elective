CREATE DATABASE IF NOT EXISTS mailflow
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE mailflow;

CREATE TABLE IF NOT EXISTS messages (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  mailbox_uid INT UNSIGNED    NOT NULL,
  from_email  VARCHAR(254)    NOT NULL DEFAULT '',
  from_name   VARCHAR(190)    NOT NULL DEFAULT '',
  subject     VARCHAR(998)    NOT NULL DEFAULT '',
  preview     VARCHAR(255)    NOT NULL DEFAULT '',
  body        LONGTEXT        NULL,
  date        DATETIME        NULL,
  seen        TINYINT(1)      NOT NULL DEFAULT 0,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mailbox_uid (mailbox_uid),
  KEY idx_messages_seen (seen),
  KEY idx_messages_date (date)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS settings (
  setting_key   VARCHAR(64)  NOT NULL,
  setting_value VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (setting_key)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
  ('mailflow_api_key',  'change-me-to-a-long-random-string'),
  ('mailflow_mailbox',  'yesdaddy@celllaunch.shop'),
  ('mailflow_imap_host','imap.hostinger.com'),
  ('mailflow_imap_port','993'),
  ('mailflow_smtp_host','smtp.hostinger.com'),
  ('mailflow_smtp_port','587');

INSERT INTO messages
  (mailbox_uid, from_email, from_name, subject, preview, body, date, seen)
VALUES
  (1, 'hello@flutter.dev', 'Flutter Team',
   'Welcome to Flutter 3.44',
   'We are excited to announce the latest stable release of Flutter.',
   'Hey there,\n\nWe are excited to announce the latest stable release of Flutter with a brand new liquid glass rendering engine.\n\nCheck the release notes for everything that changed.\n\n— The Flutter Team',
   NOW() - INTERVAL 12 MINUTE, 0),
  (2, 'noreply@hostinger.com', 'Hostinger',
   'Your mailbox yesdaddy@celllaunch.shop is ready',
   'Your hosting account is live. Configure devices using the details below.',
   'Hi,\n\nYour hosting account and mailbox are live. Use the "Connect Devices" screen in hPanel to grab the IMAP/SMTP details for your mail client.\n\nRegards,\nHostinger Support',
   NOW() - INTERVAL 2 HOUR, 0),
  (3, 'notifications@apple.com', 'Apple Developer',
   'TestFlight: new build available',
   'A new build of your app is ready for internal testing.',
   'A new build of your app is available for internal testing on TestFlight.\n\n– Apple Developer',
   NOW() - INTERVAL 1 DAY, 1);