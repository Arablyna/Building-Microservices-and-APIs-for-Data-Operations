Setting Up Pluggable Databases for Product and Inventory Management
This README provides an overview of the setup process for managing product and inventory data using Oracle Database pluggable databases (PDBs).

Prerequisites:
Before proceeding with the setup, ensure you have the following:

Oracle Database 21c installed and configured.
Access to the Oracle Database instance.
Basic understanding of SQL scripting and Oracle Database concepts.
Folder Structure:
Create Folders for PDBs:

You need to create folders named inventory_pdb and product_pdb in the same path as the oradata/orclcdb/pdbseed folder.

Creating Pluggable Databases:
Script for PDB Creation:

Use the provided SQL scripts to create pluggable databases for inventory and product management.
Ensure to modify the file paths in the scripts according to your environment.

Communication Between PDBs:
The communication between the product and inventory PDBs is facilitated through Advanced Queueing (AQ).
Messages containing product data are sent from the product PDB to the inventory PDB using queues.
This enables real-time data synchronization and inventory management.

Setting Up Microservices:
Virtual Environments (venv):

Create separate virtual environments (venv) for each microservice.

Install the Oracle Instant Client within each venv using the following link: Oracle Instant Client Downloads

Ensure you install instantclient-basic-windows.x64-21.13.0.0.0dbru\instantclient_21_13, and make sure to put its path in microservice's view:
cx_Oracle.init_oracle_client(lib_dir=r"C:\Users\Microsoft\Downloads\instantclient-basic-windows.x64-21.13.0.0.0dbru\instantclient_21_13")
