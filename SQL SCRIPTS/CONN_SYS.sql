-- Creating PDBs
CREATE PLUGGABLE DATABASE order_pdb
    ADMIN USER admin IDENTIFIED BY Oracle21c
    FILE_NAME_CONVERT = (
        'C:\Oracle_21c\oradata\ORCL\pdbseed',
        'C:\Oracle_21c\oradata\ORCL\order_pdb'
    );

CREATE PLUGGABLE DATABASE product_pdb
    ADMIN USER admin IDENTIFIED BY Oracle21c
    FILE_NAME_CONVERT = (
        'C:\Oracle_21c\oradata\ORCL\pdbseed',
        'C:\Oracle_21c\oradata\ORCL\product_pdb'
    );

CREATE PLUGGABLE DATABASE inventory_pdb
    ADMIN USER admin IDENTIFIED BY Oracle21c
    FILE_NAME_CONVERT = (
        'C:\Oracle_21c\oradata\ORCL\pdbseed',
        'C:\Oracle_21c\oradata\ORCL\inventory_pdb'
    );

-- Opening PDBs
ALTER PLUGGABLE DATABASE product_pdb OPEN;
ALTER PLUGGABLE DATABASE order_pdb OPEN;
ALTER PLUGGABLE DATABASE inventory_pdb OPEN;

-- Granting Privileges to order_pdb
ALTER SESSION SET CONTAINER = order_pdb;
GRANT CREATE USER TO admin;
GRANT CREATE SESSION, RESOURCE, CONNECT TO admin WITH ADMIN OPTION;
GRANT ALTER USER TO admin;
GRANT GRANT ANY PRIVILEGE TO admin;
GRANT EXECUTE ON dbms_aqadm TO admin WITH GRANT OPTION;
GRANT EXECUTE ON dbms_aq TO admin WITH GRANT OPTION;
GRANT aq_administrator_role TO admin WITH ADMIN OPTION;
GRANT CREATE TYPE TO admin;
GRANT CREATE PROCEDURE TO admin;
GRANT CREATE PUBLIC DATABASE LINK TO orders_service;
GRANT EXECUTE ON dbms_aqadm TO orders_service;
GRANT EXECUTE ON dbms_aq TO orders_service;
GRANT CREATE SESSION TO orders_service;
GRANT SELECT ON product_queue_table TO product_service;
GRANT CREATE SESSION TO orders_service;
GRANT CREATE DATABASE LINK TO orders_service;


-- Granting Privileges to product_pdb
ALTER SESSION SET CONTAINER = product_pdb;
GRANT CREATE USER TO admin;
GRANT CREATE SESSION, RESOURCE, CONNECT TO admin WITH ADMIN OPTION;
GRANT ALTER USER TO admin;
GRANT GRANT ANY PRIVILEGE TO admin;
GRANT EXECUTE ON dbms_aqadm TO admin WITH GRANT OPTION;
GRANT EXECUTE ON dbms_aq TO admin WITH GRANT OPTION;
GRANT aq_administrator_role TO admin WITH ADMIN OPTION;
GRANT CREATE SESSION TO product_service;
GRANT CREATE PUBLIC DATABASE LINK TO product_service;

-- Granting Privileges to inventory_pdb
ALTER SESSION SET CONTAINER = inventory_pdb;
GRANT CREATE USER TO admin;
GRANT CREATE SESSION, RESOURCE, CONNECT TO admin WITH ADMIN OPTION;
GRANT ALTER USER TO admin;
GRANT GRANT ANY PRIVILEGE TO admin;
GRANT EXECUTE ON dbms_aqadm TO admin WITH GRANT OPTION;
GRANT EXECUTE ON dbms_aq TO admin WITH GRANT OPTION;
GRANT aq_administrator_role TO admin WITH ADMIN OPTION;
