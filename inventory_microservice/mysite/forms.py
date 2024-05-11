from django import forms
from .models import ProductInventory

class ProductInventoryForm(forms.ModelForm):
    class Meta:
        model = ProductInventory
        fields = ['product_code', 'quantity']



