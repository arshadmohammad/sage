DROP DATABASE IF EXISTS ranger;
create database ranger;
DROP USER IF EXISTS rangeradmin;
create user rangeradmin identified by 'rangeradmin';
DROP USER IF EXISTS rangerlogger;
create user rangerlogger identified by 'rangerlogger';