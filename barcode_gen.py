from barcode import Code128
from barcode.writer import ImageWriter
import os

# The alphanumeric string you want to encode
data = 'f34gre3wd'

# Create the barcode object using the Code128 format
# The writer=ImageWriter() argument tells the library to generate a PNG image
barcode_obj = Code128(data, writer=ImageWriter())

# Save the barcode image with the filename 'f34gre3wd_barcode.png'
# The save() method automatically creates the image file
filename = barcode_obj.save('f34gre3wd_barcode')

print(f"Barcode image saved as: {filename}.png")

# Optional: To verify the file was created
if os.path.exists(f"{filename}.png"):
    print("File exists and was created successfully!")
else:
    print("Error: File was not created.")
