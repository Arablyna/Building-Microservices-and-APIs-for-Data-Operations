from django.shortcuts import render , redirect
from django.views.decorators.http import require_POST

from django.contrib import messages
from django.core.paginator import EmptyPage, PageNotAnInteger, Paginator 

from .models import product
from .forms import productform
from django.db import connection


# Create your views here.


def home_view(request):
    all_products = product.objects.order_by("id")
   
    paginator = Paginator(all_products,5,1)
    pageNo = request.GET.get('page',1)
    try:
        products = paginator.get_page(pageNo)
    except PageNotAnInteger:
        products = paginator.page(1)
    except EmptyPage:
        products = paginator.page(paginator.num_pages)

    form = productform()
    context = {'products' : products, 'productform' : form, "productCount" : all_products.count() }

    return render(request,'inventory.html',context)

@require_POST
def add_product(request):
    if request.method == 'POST':
        form = productform(request.POST)
        if form.is_valid():
            # Extract form data
            product_code = form.cleaned_data['product_code']
            name = form.cleaned_data['name']
            quantity = form.cleaned_data['quantity']

            # Call the stored procedure
            with connection.cursor() as cursor:
                cursor.callproc('add_product', [product_code, name, quantity])

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

        # Call the stored procedure to edit the product
        with connection.cursor() as cursor:
            cursor.callproc('edit_product', [pk, product_code, name, quantity])

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
    return redirect('home')