import os
from collections import defaultdict

DATASET_PATH = "data"
SPLITS = ["train", "valid", "test"]


def count_instances_in_labels(labels_path):
    total_instances = 0
    class_counts = defaultdict(int)

    for filename in os.listdir(labels_path):
        if not filename.endswith(".txt"):
            continue

        file_path = os.path.join(labels_path, filename)

        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                class_id = int(line.split()[0])
                total_instances += 1
                class_counts[class_id] += 1

    return total_instances, class_counts


def main():
    print("Analyzing dataset label distribution...\n")

    overall_total = 0
    overall_class_counts = defaultdict(int)

    for split in SPLITS:
        labels_dir = os.path.join(DATASET_PATH, split, "labels")

        if not os.path.exists(labels_dir):
            print(f"Labels folder not found: {labels_dir}")
            continue

        split_total, split_class_counts = count_instances_in_labels(labels_dir)

        print(f"===== {split.upper()} =====")
        print(f"Total instances: {split_total}")

        for cls, count in sorted(split_class_counts.items()):
            print(f"Class {cls}: {count}")

        overall_total += split_total
        for cls, count in split_class_counts.items():
            overall_class_counts[cls] += count

        print()

    print("===== OVERALL DATASET =====")
    print(f"Total instances: {overall_total}")

    for cls, count in sorted(overall_class_counts.items()):
        print(f"Class {cls}: {count}")


if __name__ == "__main__":
    main()