from ultralytics import YOLO

if __name__ == "__main__":
    model = YOLO("models/best.pt")

    results = model.predict(
        source="sample.jpg",
        imgsz=640,
        conf=0.25,
        save=True
    )

    print("Prediction completed.")