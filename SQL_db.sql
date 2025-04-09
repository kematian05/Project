SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT = @@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS = @@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION = @@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

drop database if exists psychCare;
create database psychCare;
use psychCare;

DROP TABLE IF EXISTS `admin`;
CREATE TABLE IF NOT EXISTS `admin`
(
    `aemail`    varchar(255) NOT NULL,
    `apassword` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`aemail`)
) ENGINE = MyISAM
  DEFAULT CHARSET = latin1;


INSERT INTO `admin` (`aemail`, `apassword`)
VALUES ('admin@admin.com', '5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5');


DROP TABLE IF EXISTS `appointment`;
CREATE TABLE IF NOT EXISTS `appointment`
(
    `appoid`       int(11)      NOT NULL AUTO_INCREMENT,
    `pid`          int(10)           DEFAULT NULL,
    `apponum`      int(3)            DEFAULT NULL,
    `scheduleid`   int(10)           DEFAULT NULL,
    `appodate`     date              DEFAULT NULL,
    `meeting_link` VARCHAR(512) NULL DEFAULT NULL,
    PRIMARY KEY (`appoid`),
    KEY `pid` (`pid`),
    KEY `scheduleid` (`scheduleid`)
) ENGINE = MyISAM
  AUTO_INCREMENT = 2
  DEFAULT CHARSET = latin1;

INSERT INTO `appointment` (`appoid`, `pid`, `apponum`, `scheduleid`, `appodate`, `meeting_link`)
VALUES (1, 1, 1, 1, '2030-01-01', 'https://youtu.be/dQw4w9WgXcQ?si=ttWWDGApmKW0ep4F');


DROP TABLE IF EXISTS `doctor`;
CREATE TABLE IF NOT EXISTS `doctor`
(
    `docid`       int(11) NOT NULL AUTO_INCREMENT,
    `docemail`    varchar(255) DEFAULT NULL,
    `docname`     varchar(255) DEFAULT NULL,
    `docpassword` varchar(255) DEFAULT NULL,
    `docnic`      varchar(15)  DEFAULT NULL,
    `doctel`      varchar(15)  DEFAULT NULL,
    `specialties` int(2)       DEFAULT NULL,
    PRIMARY KEY (`docid`),
    KEY `specialties` (`specialties`)
) ENGINE = MyISAM
  AUTO_INCREMENT = 2
  DEFAULT CHARSET = latin1;


INSERT INTO `doctor` (`docid`, `docemail`, `docname`, `docpassword`, `docnic`, `doctel`, `specialties`)
VALUES (1, 'therapist@test.com', 'Test Therapist', '5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5',
        '000000000', '0110000000', 1);


DROP TABLE IF EXISTS `patient`;
CREATE TABLE IF NOT EXISTS `patient`
(
    `pid`       int(11) NOT NULL AUTO_INCREMENT,
    `pemail`    varchar(255) DEFAULT NULL,
    `pname`     varchar(255) DEFAULT NULL,
    `ppassword` varchar(255) DEFAULT NULL,
    `paddress`  varchar(255) DEFAULT NULL,
    `pnic`      varchar(15)  DEFAULT NULL,
    `pdob`      date         DEFAULT NULL,
    `ptel`      varchar(15)  DEFAULT NULL,
    PRIMARY KEY (`pid`)
) ENGINE = MyISAM
  AUTO_INCREMENT = 3
  DEFAULT CHARSET = latin1;


INSERT INTO `patient` (`pid`, `pemail`, `pname`, `ppassword`, `paddress`, `pnic`, `pdob`, `ptel`)
VALUES (1, 'client@test.com', 'Test Client', '5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5',
        'Azerbaijan', '0000000000', '2000-01-01', '0120000000');


DROP TABLE IF EXISTS `schedule`;
CREATE TABLE IF NOT EXISTS `schedule`
(
    `scheduleid`   int(11) NOT NULL AUTO_INCREMENT,
    `docid`        varchar(255) DEFAULT NULL,
    `title`        varchar(255) DEFAULT NULL,
    `scheduledate` date         DEFAULT NULL,
    `scheduletime` time         DEFAULT NULL,
    `nop`          int(4)       DEFAULT NULL,
    PRIMARY KEY (`scheduleid`),
    KEY `docid` (`docid`)
) ENGINE = MyISAM
  AUTO_INCREMENT = 9
  DEFAULT CHARSET = latin1;


INSERT INTO `schedule` (`scheduleid`, `docid`, `title`, `scheduledate`, `scheduletime`, `nop`)
VALUES (1, '1', 'Test Session', '2030-01-01', '18:00:00', 50);


DROP TABLE IF EXISTS `specialties`;
CREATE TABLE IF NOT EXISTS `specialties`
(
    `id`    int(2) NOT NULL,
    `sname` varchar(50) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE = MyISAM
  DEFAULT CHARSET = latin1;


INSERT INTO `specialties` (`id`, `sname`)
VALUES (1, 'Physical Therapist'),
       (2, 'Mental Health Therapist'),
       (3, 'Occupational Therapist'),
       (4, 'Speech Therapist'),
       (5, 'Massage Therapist'),
       (6, 'Chiropractor'),
       (7, 'Pediatric Therapist'),
       (8, 'Geriatric Therapist'),
       (9, 'Cardiac Rehabilitation Therapist'),
       (10, 'Sports Therapist'),
       (11, 'Rehabilitation Therapist'),
       (12, 'Pain Management Therapist'),
       (13, 'Neurological Therapist'),
       (14, 'Cognitive Behavioral Therapist'),
       (15, 'Family Therapist'),
       (16, 'Marriage and Couples Therapist'),
       (17, 'Addiction Therapist'),
       (18, 'Art Therapist'),
       (19, 'Music Therapist'),
       (20, 'Animal-Assisted Therapist'),
       (21, 'Hypnotherapist'),
       (22, 'Aquatic Therapist'),
       (23, 'Post-Surgical Therapist'),
       (24, 'Trauma Therapist'),
       (25, 'Forensic Therapist'),
       (26, 'Grief Counselor'),
       (27, 'LGBTQ+ Therapist'),
       (28, 'Parenting Coach'),
       (29, 'Elder Care Therapist'),
       (30, 'Workplace Stress Therapist'),
       (31, 'Behavioral Therapist'),
       (32, 'Cognitive Therapist'),
       (33, 'Dialectical Behavior Therapist'),
       (34, 'Gestalt Therapist'),
       (35, 'EMDR Therapist'),
       (36, 'Equine-Assisted Therapist'),
       (37, 'Somatic Therapist'),
       (38, 'Sexuality Therapist'),
       (39, 'Trauma-Informed Therapist'),
       (40, 'Mindfulness Therapist'),
       (41, 'Aromatherapy Therapist'),
       (42, 'Play Therapist'),
       (43, 'Transpersonal Therapist'),
       (44, 'Ecotherapy'),
       (45, 'Existential Therapist'),
       (46, 'Clinical Psychotherapist'),
       (47, 'School Counselor'),
       (48, 'Psychodynamic Therapist'),
       (49, 'Art Therapy Counselor'),
       (50, 'Dance/Movement Therapist'),
       (51, 'Motivational Therapist'),
       (52, 'Solution-Focused Therapist'),
       (53, 'Narrative Therapist'),
       (54, 'Pastoral Counselor'),
       (55, 'Integrative Therapist'),
       (56, 'Sports Psychology Therapist'),
       (57, 'Hypnotherapy Counselor'),
       (58, 'Addiction Recovery Therapist'),
       (59, 'Marriage and Family Therapist');

DROP TABLE IF EXISTS `webuser`;
CREATE TABLE IF NOT EXISTS `webuser`
(
    `email`    varchar(255) NOT NULL,
    `usertype` char(1) DEFAULT NULL,
    PRIMARY KEY (`email`)
) ENGINE = MyISAM
  DEFAULT CHARSET = latin1;


INSERT INTO `webuser` (`email`, `usertype`)
VALUES ('admin@admin.com', 'a'),
       ('therapist@test.com', 'd'),
       ('client@test.com', 'p');
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT = @OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS = @OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION = @OLD_COLLATION_CONNECTION */;
