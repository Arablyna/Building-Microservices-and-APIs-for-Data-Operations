-- Create a new user for the product service
CREATE USER product_service IDENTIFIED BY Oracle21c;

-- Grant basic connection and resource privileges to the product service user
GRANT CONNECT, RESOURCE TO product_service;

-- Allow unlimited quota on the SYSTEM tablespace for the product service user
ALTER USER product_service QUOTA UNLIMITED ON SYSTEM;

-- Grant necessary permissions for Advanced Queueing to the product service user
GRANT EXECUTE ON dbms_aqadm TO product_service;
GRANT EXECUTE ON dbms_aq TO product_service;
GRANT aq_administrator_role TO product_service;

-- Create tables for product service
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) UNIQUE
);

CREATE TABLE product (
    id SERIAL PRIMARY KEY,
    product_code VARCHAR(5) UNIQUE,
    name VARCHAR(200),
    description VARCHAR(500),
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    price NUMERIC(10, 2)
);

-- Define the category type
CREATE OR REPLACE TYPE category_t AS OBJECT (
  category_id NUMBER,
  category_name VARCHAR2(200)
);

-- Define the product message type for sending to the inventory
CREATE OR REPLACE TYPE product_message_to_inventory_t AS OBJECT (
  product_code VARCHAR2(5),
  name VARCHAR2(200),
  description VARCHAR2(500),
  category category_t,  -- Include the category as a nested object
  price NUMBER(10, 2)
);

-- Create a package for sending messages from product to inventory
CREATE OR REPLACE PACKAGE product_to_inventory_p AS
  PROCEDURE send_message (
    queue_name        IN VARCHAR2,
    product_content   IN product_message_to_inventory_t
  );
END;
/

-- Create the package body for sending messages from product to inventory
CREATE OR REPLACE PACKAGE BODY product_to_inventory_p AS
  PROCEDURE send_message (
    queue_name        IN VARCHAR2,
    product_content   IN product_message_to_inventory_t
  ) IS
    enq_msgid RAW(16);
    eopt      DBMS_AQ.ENQUEUE_OPTIONS_T;
    mprop     DBMS_AQ.MESSAGE_PROPERTIES_T;
  BEGIN
    DBMS_AQ.ENQUEUE(
      queue_name        => queue_name,
      enqueue_options   => eopt,
      message_properties=> mprop,
      payload           => product_content,
      msgid             => enq_msgid
    );
    COMMIT;
  END send_message;
END;

-- Create the queue table, queue, and start the queue in the inventory service
BEGIN
  DBMS_AQADM.CREATE_QUEUE_TABLE(
    queue_table        => 'product_inventory_queue_table',
    queue_payload_type => 'product_message_to_inventory_t',
    multiple_consumers => TRUE
  );

  DBMS_AQADM.CREATE_QUEUE(
    queue_name  => 'product_inventory_queue',
    queue_table => 'product_inventory_queue_table'
  );

  DBMS_AQADM.START_QUEUE(queue_name => 'product_inventory_queue');
END;

-- Create a public database link from the product service to the inventory service
CREATE PUBLIC DATABASE LINK link_to_inventory
  CONNECT TO inventory_service IDENTIFIED BY Oracle21c
  USING '(DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = inventory_pdb)
    )
  )';

-- Set up propagation from product to inventory
BEGIN
  dbms_aqadm.schedule_propagation(
    queue_name     => 'product_inventory_queue',
    destination    => 'LINK_TO_INVENTORY',
    start_time     => SYSTIMESTAMP,
    duration       => NULL,
    latency        => 0
  );
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error while scheduling propagation: ' || sqlerrm);
END;

-- Add a subscriber for the product_inventory_queue
DECLARE
    subscriber sys.aq$_agent;
BEGIN
    subscriber := sys.aq$_agent('inventory_service', 'inventory_service.product_inventory_queue@link_to_inventory', NULL);
    dbms_aqadm.add_subscriber(queue_name => 'product_inventory_queue', subscriber => subscriber);
EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('Error while adding subscribers: ' || sqlerrm);
END;

-- Insert some categories for testing purposes
INSERT INTO categories (id, name)
VALUES (1, 'Electronics');

INSERT INTO categories (id, name)
VALUES (2, 'Clothing');

INSERT INTO categories (id, name)
VALUES (3, 'Books');

-- Procedure to insert a product and send a message to inventory
CREATE OR REPLACE PROCEDURE insert_product_and_send_message (
    p_product_code IN VARCHAR2,
    p_name IN VARCHAR2,
    p_description IN VARCHAR2,
    p_category_id IN NUMBER,
    p_price IN NUMBER
) IS
    v_product_message product_message_to_inventory_t;
    v_category_name categories.name%TYPE;
BEGIN
    -- Insert data into the product table
    INSERT INTO product (product_code, name, description, category_id, price)
    VALUES (p_product_code, p_name, p_description, p_category_id, p_price);

    -- Retrieve the category name based on the category_id
    SELECT name INTO v_category_name FROM categories WHERE id = p_category_id;

    -- Construct the product message
    v_product_message := product_message_to_inventory_t(
        p_product_code,
        p_name,
        p_description,
        category_t(p_category_id, v_category_name),
        p_price
    );

    -- Send the message from Product Service to Inventory Service
    product_to_inventory_p.send_message(
        queue_name => 'product_inventory_queue',
        product_content => v_product_message
    );
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Category not found for category_id: ' || p_category_id);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;

-- Trigger to send a message to the inventory service after inserting a new product
CREATE OR REPLACE TRIGGER trg_send_product_to_inventory
AFTER INSERT ON product
FOR EACH ROW
DECLARE
    v_product_message product_message_to_inventory_t;
    v_category_name categories.name%TYPE;
BEGIN
    -- Retrieve the category name based on the category_id
    SELECT name INTO v_category_name FROM categories WHERE id = :new.category_id;

    -- Construct the product message
    v_product_message := product_message_to_inventory_t(
        :new.product_code,
        :new.name,
        :new.description,
        category_t(:new.category_id, v_category_name),
        :new.price
    );

    -- Send the message from Product Service to Inventory Service
    product_to_inventory_p.send_message(
        queue_name => 'product_inventory_queue',
        product_content => v_product_message
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Category not found for category_id: ' || :new.category_id);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);

END;

-- Testing the insert_product_and_send_message procedure
BEGIN
    insert_product_and_send_message('P001', 'Sample Product', 'Sample Description', 1, 15.00);
END;

-- View the product table after insertion
SELECT * FROM product;
