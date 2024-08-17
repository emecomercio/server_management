import os
import cloudinary
import cloudinary.uploader
from cloudinary.utils import cloudinary_url

# Configuration       
cloudinary.config( 
    cloud_name = "dtvdlk7fi", 
    api_key = "327341694125465", 
    api_secret = "pfYuQvN64KkVzyrpZmGaWZ9RHds",
    secure=True
)

def upload_image(url, public_id):
    try:
        upload_result = cloudinary.uploader.upload(url, public_id=public_id)
        return upload_result["secure_url"]
    except cloudinary.exceptions.Error as e:
        print(f"Error uploading image: {e}")
        return None

def optimize_image(public_id):
    optimize_url, _ = cloudinary_url(public_id, fetch_format="auto", quality="auto")
    return optimize_url

def auto_crop_image(public_id, width, height):
    auto_crop_url, _ = cloudinary_url(public_id, width=width, height=height, crop="auto", gravity="auto")
    return auto_crop_url


while True:
    os.system('clear')
    url = input("Ingresa URL o ruta local de Imagen: ")
    public_id = input("Ingresa nombre de Imagen: ")
    auto_crop_urls = {}

    while True:
            os.system('clear')
            print("Desea agregar un recorte personalizado? (s/n)")
            if input() == "n":
                break
            print("-------------------------------------")
            print("Ingresa ancho")
            width = int(input())
            print("Ingresa alto")
            height = int(input())
            size = f"{width}x{height}"
            auto_crop_url = auto_crop_image(public_id, width, height)
            auto_crop_urls[size] = auto_crop_url

    print("------------\"Secure URL\"------------")
    secure_url = upload_image(url, public_id)
    if secure_url:
        print(secure_url)

    print("------------\"Optimized URL\"------------")
    if secure_url:
        print(optimize_image(public_id))

    if secure_url:
        for size, auto_crop_url in auto_crop_urls.items():
            print(f"------------\"Custom {size} URL\"------------")
            print(auto_crop_url)
    

    print("Desea salir? (s/n)")
    if input() == "s":
        break
os.system('clear')