from django.shortcuts import render , redirect
from django.views.decorators.http import require_POST

from django.contrib import messages
from django.core.paginator import EmptyPage, PageNotAnInteger, Paginator 

from .models import Category, product
from .forms import ProductForm
from django.db import connection
import cx_Oracle
cx_Oracle.init_oracle_client(lib_dir=r"C:\Users\Microsoft\Downloads\instantclient-basic-windows.x64-21.13.0.0.0dbru\instantclient_21_13")


from django.http import JsonResponse


@require_POST
def add_product(request):
    if request.method == 'POST':
        form = ProductForm(request.POST)
        if form.is_valid():
            product_code = form.cleaned_data['product_code']
            name = form.cleaned_data['name']
            description = form.cleaned_data['description']
            category = form.cleaned_data['category']
            price = form.cleaned_data['price']

            try:
                with connection.cursor() as cursor:
                    cursor.callproc('insert_product_and_send_message', [product_code, name, description, category.id, price])

                messages.success(request, "Product created successfully!")
                return redirect('home')
            except Exception as e:
                messages.error(request, "An error occurred while adding the product.")
        else:
            messages.error(request, "Form is not valid. Please correct the errors.")
    else:
        form = ProductForm()

    return render(request, 'add_product.html', {'form': form})

def home_view(request):
    # Connect to the Oracle database
    connection = cx_Oracle.connect(
        user="product_service",
        password="Oracle21c",
        dsn="localhost:1521/product_pdb"
    )

    with connection.cursor() as cursor:
        # Call the stored procedure to get all products
        products_cursor = cursor.var(cx_Oracle.CURSOR)
        cursor.callproc('get_all_products', [products_cursor])

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

"""
@require_POST
def add_product(request):
    if request.method == 'POST':
        form = productform(request.POST)
        if form.is_valid():
            # Extract form data
            product_code = form.cleaned_data['product_code']
            name = form.cleaned_data['name']
            quantity = form.cleaned_data['quantity']
            price = form.cleaned_data['price']  # Add this line to extract price

            # Call the stored procedure
            with connection.cursor() as cursor:
                cursor.callproc('add_product', [product_code, name, quantity, price])  # Include price here

            messages.success(request, "Product created successfully!")
            return redirect('home')
        else:
            messages.error(request, "Form is not valid. Please correct the errors.")
    else:
        form = productform()

    return render(request, 'add_product.html', {'form': form})


@require_POST
def edit_product(request, pk):
    item = product.objects.get(id=pk)
    form = productform(request.POST, instance=item)
    if form.is_valid():
        # Extract form data
        product_code = form.cleaned_data['product_code']
        name = form.cleaned_data['name']
        quantity = form.cleaned_data['quantity']
        price = form.cleaned_data['price']  # Added price extraction

        # Call the stored procedure to edit the product
        with connection.cursor() as cursor:
            cursor.callproc('edit_product', [pk, product_code, name, quantity, price])  # Passed price parameter

        messages.success(request, "Product edited successfully!")
    else:
        for err in form.errors:
            messages.error(request, form.errors[err][0])
    
    return redirect('home')

@require_POST
def delete_product(request, pk):
    # Call the stored procedure to delete the product
    with connection.cursor() as cursor:
        cursor.callproc('delete_product', [pk])

    messages.success(request, "Product deleted successfully!")
    return redirect('home')"""