from django.shortcuts import get_object_or_404, render , redirect
from django.views.decorators.http import require_POST

from django.contrib import messages
from django.core.paginator import EmptyPage, PageNotAnInteger, Paginator 

from .models import *
from .forms import *
from django.db import connection
import cx_Oracle
cx_Oracle.init_oracle_client(lib_dir=r"C:\Users\Microsoft\Downloads\instantclient-basic-windows.x64-21.13.0.0.0dbru\instantclient_21_13")

# Connect to the Oracle database
connection = cx_Oracle.connect(
    user="inventory_service",
    password="Oracle21c",
    dsn="localhost:1521/inventory_pdb"
)

def home_view(request):
    # Connect to the Oracle database

    with connection.cursor() as cursor:
        # Call the stored procedure to get all product inventory
        inventory_cursor = cursor.var(cx_Oracle.CURSOR)
        cursor.callproc('get_all_product_inventory', [inventory_cursor])

        # Fetch the result set from the cursor
        inventory = inventory_cursor.getvalue()

        # Convert the fetched inventory into a list of dictionaries for easier manipulation in the template
        inventory_list = []
        if inventory:
            for inventory_data in inventory:
                inventory_dict = {
                    'product_code': inventory_data[0],
                    'quantity': inventory_data[1],
                }
                inventory_list.append(inventory_dict)

    # Paginate the inventory
    paginator = Paginator(inventory_list, 5)
    page_number = request.GET.get('page', 1)
    try:
        inventory_page = paginator.page(page_number)
    except PageNotAnInteger:
        inventory_page = paginator.page(1)
    except EmptyPage:
        inventory_page = paginator.page(paginator.num_pages)

    # Prepare form
    form = ProductInventoryForm()

    # Prepare context
    context = {
        'inventory': inventory_page,
        'productform': form,
        'inventoryCount': len(inventory_list),
    }

    return render(request, 'inventory.html', context)
@require_POST
def edit_product_inventory(request, pk):
    if request.method == 'POST':
        # Extract form data
        product_code = pk
        quantity = request.POST.get('quantity')

        # Call the stored procedure to edit the product inventory
        with connection.cursor() as cursor:
            cursor.callproc('edit_product_inventory', [product_code, quantity])

            try:
                cursor.execute('COMMIT')
                messages.success(request, "Product inventory edited successfully!")
            except Exception as e:
                cursor.execute('ROLLBACK')
                messages.error(request, str(e))

            return redirect('home')

    return redirect('home')