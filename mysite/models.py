from django.db import models

# Create your models here.

class Category(models.Model):
    name = models.CharField(max_length=200, unique=True)

    class Meta:
        db_table = 'categories'

    def __str__(self):
        return self.name
class product(models.Model):
    product_code = models.CharField(max_length=5, unique=True)
    name = models.CharField(max_length=200)
    description = models.CharField(max_length=500)
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    price = models.DecimalField(max_digits=10, decimal_places=2)  # Adding the price field


    class Meta:
        db_table = 'product'

    def __str__(self):
        return self.name