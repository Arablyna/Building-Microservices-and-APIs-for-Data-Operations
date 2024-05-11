from django.db import models

# Create your models here.


from django.db import models

class ProductInventory(models.Model):
    product_code = models.CharField(max_length=5, primary_key=True)
    quantity = models.IntegerField()

    class Meta:
        db_table = 'product_inventory'
