import tkinter as tk
from tkinter import messagebox
from datetime import datetime

# Crop Data (same as your Glide app)
crops = {
    "Wheat": {
        "sowing": "15 Nov–10 Dec",
        "irrigation": "After 20 days",
        "fertilizer": "DAP + Urea"
    },
    "Rice": {
        "sowing": "May–June",
        "irrigation": "Standing water",
        "fertilizer": "Nitrogen"
    },
    "Maize": {
        "sowing": "Feb–Mar / July",
        "irrigation": "Moderate",
        "fertilizer": "NPK"
    },
    "Potato": {
        "sowing": "Oct–Nov",
        "irrigation": "Light but frequent",
        "fertilizer": "Potash"
    }
}

# Smart Advice Function
def get_advice(crop_name):
    month = datetime.now().month

    if crop_name == "Wheat" and month == 11:
        return "Best time to sow wheat!"
    elif crop_name == "Rice" and month in [6, 7]:
        return "Good time for rice transplanting"
    elif month > 6 and crop_name == "Maize":
        return "Suitable for maize sowing"
    else:
        return "Normal conditions"

# Show Crop Details
def show_details(crop_name):
    data = crops[crop_name]
    advice = get_advice(crop_name)

    message = f"""
Crop: {crop_name}

Sowing: {data['sowing']}
Irrigation: {data['irrigation']}
Fertilizer: {data['fertilizer']}

Advice: {advice}
"""
    messagebox.showinfo("Crop Details", message)

def main():
    # Main Window
    root = tk.Tk()
    root.title("Smart Farming - Sahiwal")
    root.geometry("400x400")

    title = tk.Label(root, text="Select Crop", font=("Arial", 16))
    title.pack(pady=20)

    # Buttons for crops
    for crop in crops.keys():
        btn = tk.Button(root, text=crop, width=20,
                        command=lambda c=crop: show_details(c))
        btn.pack(pady=5)

    root.mainloop()


if __name__ == "__main__":
    main()     