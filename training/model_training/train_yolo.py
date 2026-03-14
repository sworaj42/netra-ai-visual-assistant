from ultralytics import YOLO

DATASET_YAML = "data/dataset.yaml"
TRAIN_DIR = "results"
RUN_NAME = "yolo11s_train"
BEST_MODEL_PATH = f"{TRAIN_DIR}/{RUN_NAME}/weights/best.pt"


def train_model():
    model = YOLO("yolo11s.pt")

    model.train(
        data=DATASET_YAML,
        epochs=100,
        patience=10,
        imgsz=640,
        batch=16,
        device=0,
        amp=True,
        workers=8,
        cache="ram",
        optimizer="AdamW",
        lr0=0.001,
        weight_decay=0.0005,
        cos_lr=True,
        pretrained=True,
        save=True,
        project=TRAIN_DIR,
        name=RUN_NAME
    )


def validate_model():
    model = YOLO(BEST_MODEL_PATH)

    val_results = model.val(
        data=DATASET_YAML,
        split="val",
        imgsz=640,
        device=0
    )

    print("\n=== Validation Results ===")
    print(val_results)


def test_model():
    model = YOLO(BEST_MODEL_PATH)

    test_results = model.val(
        data=DATASET_YAML,
        split="test",
        imgsz=640,
        device=0
    )

    print("\n=== Test Results ===")
    print(test_results)

    print("\nDetailed Test Metrics:")
    try:
        for k, v in test_results.results_dict.items():
            print(f"{k}: {v}")
    except Exception:
        print(test_results)


if __name__ == "__main__":
    train_model()
    validate_model()
    test_model()