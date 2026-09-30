"""Accuracy of the integer pipeline over the MNIST test set.

Runs every test image through pipeline.infer() and through a float reference
built from the unquantized dumps in training_weights/, then reports both
accuracies and how often they agree. A gap between the two is quantization
loss; a gap in agreement on images both get right is a modelling bug.
"""

import os
import numpy as np

from pipeline import (PIXEL_SCALE, SHIFT, infer, load_weights, read_images,
                      read_labels)

DIR = os.path.dirname(os.path.abspath(__file__))
FLOAT_DIR = os.path.join(DIR, os.pardir, "training_weights")

TRAIN_SCALE = 255.0   # ToTensor() fed pixels as px/255 during training


def read_floats(name):
    with open(os.path.join(FLOAT_DIR, name)) as f:
        rows = [[float(v) for v in line.split()] for line in f if line.strip()]
    return np.array(rows, dtype=np.float64)


def infer_float(px, weights):
    wh, bh, wo, bo = weights
    relu = np.maximum(wh @ (px / TRAIN_SCALE) + bh, 0.0)
    return int(np.argmax(wo @ relu + bo))


images, labels = read_images(), read_labels()
int_weights = load_weights()
float_weights = (read_floats("hidden_weights.txt"), read_floats("hidden_biases.txt")[0],
                 read_floats("output_weights.txt"), read_floats("output_biases.txt")[0])

int_correct = float_correct = agree = 0
mismatches = []

for i, (px, label) in enumerate(zip(images, labels)):
    *_, int_pred = infer(px, int_weights)
    float_pred = infer_float(px, float_weights)

    int_correct += int_pred == label
    float_correct += float_pred == label
    agree += int_pred == float_pred
    if int_pred != label:
        mismatches.append((i, int(label), int_pred))

n = len(labels)
print(f"images            {n}")
print(f"integer accuracy  {int_correct}/{n} = {100 * int_correct / n:.2f}%")
print(f"float accuracy    {float_correct}/{n} = {100 * float_correct / n:.2f}%")
print(f"agreement         {agree}/{n} = {100 * agree / n:.2f}%")
print(f"pixel scale       integer 1/{PIXEL_SCALE}, float 1/{TRAIN_SCALE:.0f}, shift {SHIFT}")
print(f"\nfirst 10 integer misses (index, label, predicted):")
for m in mismatches[:10]:
    print(f"  {m[0]:5d}  {m[1]} -> {m[2]}")
