-- Create a new user
CREATE USER orders_service IDENTIFIED BY Oracle21c;

-- Grant basic connection and resource privileges
GRANT CONNECT, RESOURCE TO orders_service;

-- Allow unlimited quota on the SYSTEM tablespace
ALTER USER orders_service QUOTA UNLIMITED ON SYSTEM;

-- Grant necessary permissions for Advanced Queueing
GRANT EXECUTE ON dbms_aqadm TO orders_service;
GRANT EXECUTE ON dbms_aq TO orders_service;
GRANT aq_administrator_role TO orders_service;

SELECT USER FROM DUAL;
-- Create the messages_t type
CREATE OR REPLACE TYPE messages_t AS OBJECT (
  message VARCHAR2(100 CHAR)
);
/

--Create Message Type

CREATE OR REPLACE PACKAGE test_p AS
  PROCEDURE send_message (
    queue_name        IN VARCHAR2,
    message_content   IN VARCHAR2
  );
END;
/

-- Create Packages for Message Handling

CREATE OR REPLACE PACKAGE BODY test_p AS
  PROCEDURE send_message (
    queue_name        IN VARCHAR2,
    message_content   IN VARCHAR2
  ) IS
    enq_msgid RAW(16);
    eopt      DBMS_AQ.ENQUEUE_OPTIONS_T;
    mprop     DBMS_AQ.MESSAGE_PROPERTIES_T;
  BEGIN
    DBMS_AQ.ENQUEUE(
      queue_name        => queue_name,
      enqueue_options   => eopt,
      message_properties=> mprop,
      payload           => messages_t(message_content),
      msgid             => enq_msgid
    );
    COMMIT;
  END send_message;
END;
/

-- Create the queue table, queue, and start the queue

BEGIN
  DBMS_AQADM.CREATE_QUEUE_TABLE(
    queue_table        => 'order_queue_table',
    queue_payload_type => 'messages_t',
    multiple_consumers => true
  );

  DBMS_AQADM.CREATE_QUEUE(
    queue_name  => 'order_queue',
    queue_table => 'order_queue_table'
  );

  DBMS_AQADM.START_QUEUE(queue_name => 'order_queue');
END;

--Create a Database Link:

CREATE PUBLIC DATABASE LINK link_to_products
  CONNECT TO product_service IDENTIFIED BY Oracle21c
  USING '(DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = product_pdb)
    )
  )';
  
--Validate the link and check connectivity:
SELECT * FROM all_db_links WHERE db_link = 'LINK_TO_PRODUCTS';
SELECT COUNT(*) FROM PRODUCT_SERVICE.PRODUCT_QUEUE_TABLE@LINK_TO_PRODUCTS;

--Set Up Propagation

BEGIN
  dbms_aqadm.schedule_propagation(
    queue_name     => 'order_queue',
    destination    => 'LINK_TO_PRODUCTS',
    start_time     => SYSTIMESTAMP,
    duration       => NULL,
    latency        => 0
  );
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error while scheduling propagation: ' || sqlerrm);
END;

--Check the propagation setup:

SELECT
  qname,
  destination,
  message_delivery_mode,
  job_name
FROM
  user_queue_schedules
where destination like '%LINK_TO_PRODUCTS%';

--adding subsubscriber

DECLARE
    subscriber sys.aq$_agent;
BEGIN
    subscriber := sys.aq$_agent('product_service', 'product_service.product_queue@LINK_TO_PRODUCTS', NULL);
    dbms_aqadm.add_subscriber(queue_name => 'order_queue', subscriber => subscriber);
    
EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('error while adding subscribers: ' || sqlerrm);
END;

--Test the Subscriber Configuration

SELECT
    QUEUE_NAME,        
    CONSUMER_NAME AS C_NAME,
    TRANSFORMATION,  
    ADDRESS,          
    QUEUE_TO_QUEUE
FROM USER_QUEUE_SUBSCRIBERS;

--Send a Message
BEGIN
    test_p.send_message(
        queue_name => 'order_queue',
        message_content => 'hello there'
    );
END;

--Verify Message Transformation
SELECT
    transformation_id as trn_id,
    name,
    from_type,
    to_type
FROM
    user_transformations;


--Create a Database Link with the inventory service:

CREATE PUBLIC DATABASE LINK link_to_inventory
  CONNECT TO inventory_service IDENTIFIED BY Oracle21c
  USING '(DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = inventory_pdb)
    )
  )';
  
--Validate the link and check connectivity:
SELECT * FROM all_db_links WHERE db_link = 'LINK_TO_INVENTORY';

--Set Up Propagation

BEGIN
  dbms_aqadm.schedule_propagation(
    queue_name     => 'order_queue',
    destination    => 'LINK_TO_INVENTORY',
    start_time     => SYSTIMESTAMP,
    duration       => NULL,
    latency        => 0
  );
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error while scheduling propagation: ' || sqlerrm);
END;

--Check the propagation setup:

SELECT
  qname,
  destination,
  message_delivery_mode,
  job_name
FROM
  user_queue_schedules
where destination like '%LINK_TO_INVENTORY%';


CREATE OR REPLACE PROCEDURE get_product_quantity (
    p_product_code IN VARCHAR2,
    p_quantity OUT NUMBER
) AS
BEGIN
    SELECT QUANTITY INTO p_quantity
    FROM INVENTORY_SERVICE.PRODUCT_INVENTORY@LINK_TO_INVENTORY
    WHERE PRODUCT_CODE = p_product_code;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_quantity := 0; -- Or handle the case when the product code is not found
END;

--get all products:
create or replace PROCEDURE get_all_products (
    p_products OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_products FOR
    SELECT * FROM PRODUCT_SERVICE.PRODUCT@LINK_TO_PRODUCTS;
END get_all_products;


