-- Create the inventory_service user
CREATE USER inventory_service IDENTIFIED BY Oracle21c;

-- Grant basic connection and resource privileges to the inventory_service user
GRANT CONNECT, RESOURCE TO inventory_service;

-- Allow unlimited quota on the SYSTEM tablespace for the inventory_service user
ALTER USER inventory_service QUOTA UNLIMITED ON SYSTEM;

-- Grant necessary permissions for Advanced Queueing to the inventory_service user
GRANT EXECUTE ON dbms_aqadm TO inventory_service;
GRANT EXECUTE ON dbms_aq TO inventory_service;
GRANT aq_administrator_role TO inventory_service;

-- Create the product_inventory table
CREATE TABLE product_inventory (
    product_code VARCHAR2(5) PRIMARY KEY,
    quantity NUMBER
);

-- Define the product message type as an object
CREATE OR REPLACE TYPE product_message_t AS OBJECT (
  product_code VARCHAR2(5),
  name VARCHAR2(200),
  description VARCHAR2(500),
  category category_t,  -- Include the category as a nested object
  price NUMBER(10, 2)
);

-- Create the queue table, queue, and start the queue for the product_inventory
BEGIN
  DBMS_AQADM.CREATE_QUEUE_TABLE(
    queue_table        => 'product_inventory_queue_table',
    queue_payload_type => 'product_message_t',
    multiple_consumers => TRUE
  );

  DBMS_AQADM.CREATE_QUEUE(
    queue_name  => 'product_inventory_queue',
    queue_table => 'product_inventory_queue_table'
  );

  DBMS_AQADM.START_QUEUE(queue_name => 'product_inventory_queue');
END;

-- Create a procedure for event callback to handle the received messages in inventory_service
CREATE OR REPLACE PROCEDURE event_callback_inventory (
    context    RAW,
    reginfo    SYS.AQ$_REG_INFO,
    descr      SYS.AQ$_DESCRIPTOR,
    payload    RAW,
    payloadl   NUMBER
) IS
    l_dequeue_options    dbms_aq.dequeue_options_t;
    l_message_properties dbms_aq.message_properties_t;
    l_message_handle     RAW(16);
    l_payload            product_message_t;
BEGIN
    -- Configure dequeue options
    l_dequeue_options.msgid := descr.msg_id;
    l_dequeue_options.wait := dbms_aq.no_wait;
    l_dequeue_options.consumer_name := 'inventory_service';
    
    -- Dequeue the message
    dbms_aq.dequeue(
        queue_name         => descr.queue_name,
        dequeue_options    => l_dequeue_options,
        message_properties => l_message_properties,
        payload            => l_payload,
        msgid              => l_message_handle
    );

    -- Insert the received product message into the product_inventory table
    INSERT INTO product_inventory (product_code, quantity)
    VALUES (l_payload.product_code, 10); -- Assuming default quantity is 10
    
    COMMIT;
END event_callback_inventory;

-- Register the event callback procedure for message handling
BEGIN
   dbms_aq.register
      (sys.aq$_reg_info_list
         (sys.aq$_reg_info
            ('inventory_service.product_inventory_queue:inventory_service'
            ,DBMS_AQ.NAMESPACE_AQ
            ,'plsql://inventory_service.event_callback_inventory'
            ,NULL)
         ),
      1
      );
END;

-- Verify if the product_inventory table is created successfully
SELECT * FROM product_inventory;
