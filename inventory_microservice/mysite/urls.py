from django.urls import path
from . import views

urlpatterns = [
    path("",views.home_view , name = "home"),
    path("edit/<str:pk>/", views.edit_product_inventory, name="edit_product"),
]