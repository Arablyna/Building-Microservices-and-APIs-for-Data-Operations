from django.shortcuts import render , redirect
from django.views.decorators.http import require_POST

from django.contrib import messages
from django.core.paginator import EmptyPage, PageNotAnInteger, Paginator 

from .models import Category, product
from .forms import ProductForm
from django.db import connection
import cx_Oracle


from django.http import JsonResponse

cx_Oracle.init_oracle_client(lib_dir=r"C:\Users\Microsoft\Downloads\instantclient-basic-windows.x64-21.13.0.0.0dbru\instantclient_21_13")

def home_view(request):
    # Connect to the Oracle database
    connection = cx_Oracle.connect(

        user="orders_service@LINK_TO_PRODUCTS",
        password="Oracle21c",
        dsn="localhost:1521/order_pdb"
    )



    with connection.cursor() as cursor:
        # Call the stored procedure to get all products
        products_cursor = cursor.var(cx_Oracle.CURSOR)
        cursor.callproc('get_products', [products_cursor])

        # Fetch the result set from the cursor
        products = products_cursor.getvalue()

        # Print out the products to inspect the data structure
        print(products)

        # Convert the fetched products into a list of dictionaries for easier manipulation in the template
        products_list = []
        if products:  
            for product_data in products:
                product_dict = {
                    'id': product_data[0],
                    'product_code': product_data[1],
                    'name': product_data[2],
                    'description': product_data[3],
                    'category_id': product_data[4],
                    'price': product_data[5],
                    'category_name': Category.objects.get(id=product_data[4]).name  # Fetching category name

                }
                products_list.append(product_dict)

    # Paginate the products
    paginator = Paginator(products_list, 5, 1)
    page_number = request.GET.get('page', 1)
    try:
        products_page = paginator.page(page_number)
    except PageNotAnInteger:
        products_page = paginator.page(1)
    except EmptyPage:
        products_page = paginator.page(paginator.num_pages)

    # Prepare form
    form = ProductForm()

    # Prepare context
    context = {
        'products': products_page,
        'productform': form,
        'productCount': len(products_list),
    }

    return render(request, 'inventory.html', context)
