"""Train the MNIST net and dump its float weights to scripts/training_weights/.
Run it:  python3 scripts/train_minst.py
"""

import os

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

EPOCHS = 3
BATCH_SIZE = 64
LEARNING_RATE = 0.005

# Anchored to the script so paths resolve from any working directory.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_ROOT = os.path.join(SCRIPT_DIR, "data")
OUT_DIR = os.path.join(SCRIPT_DIR, "training_weights")


class MNISTInferenceNet(nn.Module):
    """784 -> 16 -> ReLU -> 10, matching the FPGA datapath."""

    def __init__(self):
        super(MNISTInferenceNet, self).__init__()
        self.flatten = nn.Flatten()
        self.hidden = nn.Linear(28 * 28, 16)
        self.relu = nn.ReLU()
        self.output = nn.Linear(16, 10)

    def forward(self, x):
        x = self.flatten(x)
        x = self.hidden(x)
        x = self.relu(x)
        x = self.output(x)
        return x


def train_model():
    """ToTensor() only, so pixels stay in [0,1]."""
    transform = transforms.Compose([transforms.ToTensor()])
    dataset = datasets.MNIST(root=DATA_ROOT, train=True, download=True,
                             transform=transform)
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)

    model = MNISTInferenceNet()
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

    print(f"Training for {EPOCHS} epochs...")
    model.train()
    for epoch in range(EPOCHS):
        total_loss = 0
        for data, target in loader:
            optimizer.zero_grad()
            loss = criterion(model(data), target)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        print(f"Epoch {epoch+1} complete. Avg loss: {total_loss/len(loader):.4f}")

    model.eval()
    return model


def save_floats(tensor, filename):
    """One row per line, space-separated floats. Biases are a single row."""
    rows = tensor.detach().tolist()
    if not isinstance(rows[0], list):
        rows = [rows]

    path = os.path.join(OUT_DIR, filename)
    with open(path, 'w') as f:
        for row in rows:
            f.write(" ".join(repr(v) for v in row) + "\n")
    print(f"Saved: {path} ({len(rows)}x{len(rows[0])})")


if __name__ == "__main__":
    model = train_model()

    os.makedirs(OUT_DIR, exist_ok=True)
    save_floats(model.hidden.weight.data, "hidden_weights.txt")   # [16, 784]
    save_floats(model.hidden.bias.data, "hidden_biases.txt")      # [16]
    save_floats(model.output.weight.data, "output_weights.txt")   # [10, 16]
    save_floats(model.output.bias.data, "output_biases.txt")      # [10]

    print("\nDone.")
