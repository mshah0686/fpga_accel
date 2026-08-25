import os
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

# =====================================================================
# 1. HARDWARE CONFIGURATION (Fixed-Point Setup)
# =====================================================================
# Using 16-bit total width with 8 fractional bits (Q8.8 format)
FRACTIONAL_BITS = 8
INT_MIN = -32768
INT_MAX = 32767

def float_to_fixed_hex(tensor):
    """Converts a PyTorch float tensor to quantized 16-bit hex strings."""
    # Scale float to fixed point
    scaled = torch.round(tensor * (1 << FRACTIONAL_BITS)).int()
    # Clamp values to prevent 16-bit overflow/underflow
    clamped = torch.clamp(scaled, INT_MIN, INT_MAX)
    
    hex_list = []
    for val in clamped.flatten().tolist():
        # Handle negative numbers for 16-bit two's complement hex
        val_unsigned = val & 0xFFFF
        hex_str = f"{val_unsigned:04x}"
        hex_list.append(hex_str)
    return hex_list

# Generated hex files land next to the RTL that $readmemh's them
WEIGHTS_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "fpga_files", "rtl", "weights"))

def save_to_hex_file(hex_data, filename):
    """Saves hex strings into a text file readable by Verilog $readmemh."""
    os.makedirs(WEIGHTS_DIR, exist_ok=True)
    path = os.path.join(WEIGHTS_DIR, filename)
    with open(path, 'w') as f:
        for hex_val in hex_data:
            f.write(f"{hex_val}\n")
    print(f"Saved: {path} ({len(hex_data)} entries)")

def save_per_neuron_hex_files(weights, prefix):
    """Dumps one file per neuron: row n of the weight matrix -> <prefix>_<n>.hex.

    Each file holds every incoming weight for a single neuron, which is exactly
    what one column BRAM of the systolic array needs preloaded.
    """
    for neuron in range(weights.shape[0]):
        save_to_hex_file(float_to_fixed_hex(weights[neuron]), f"{prefix}_{neuron}.hex")

# =====================================================================
# 2. DEFINE THE NEURAL NETWORK
# =====================================================================
class MNISTInferenceNet(nn.Module):
    def __init__(self):
        super(MNISTInferenceNet, self).__init__()
        self.flatten = nn.Flatten()
        self.hidden = nn.Linear(28 * 28, 16)
        self.relu = nn.ReLU()
        self.output = nn.Linear(16, 10)
        # Note: Softmax is omitted here because CrossEntropyLoss applies it internally,
        # and your hardware inference only needs raw scores for ArgMax.

    def forward(self, x):
        x = self.flatten(x)
        x = self.hidden(x)
        x = self.relu(x)
        x = self.output(x)
        return x

# =====================================================================
# 3. TRAINING LOOP
# =====================================================================
def train_model():
    # Load dataset (keeping inputs scaled between 0 and 1 for easier HW handling)
    transform = transforms.Compose([transforms.ToTensor()])
    train_dataset = datasets.MNIST(root='./data', train=True, download=True, transform=transform)
    train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
    
    model = MNISTInferenceNet()
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.005)
    
    print("Training model for 3 epochs...")
    model.train()
    for epoch in range(3):
        total_loss = 0
        for batch_idx, (data, target) in enumerate(train_loader):
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        print(f"Epoch {epoch+1} Complete. Avg Loss: {total_loss/len(train_loader):.4f}")
        
    return model

# =====================================================================
# 4. MAIN EXECUTION & WEIGHT EXTRACTION
# =====================================================================
if __name__ == "__main__":
    # Train the model
    trained_model = train_model()
    
    # Extract weights and biases as PyTorch tensors
    w1 = trained_model.hidden.weight.data  # Shape: [16, 784]
    b1 = trained_model.hidden.bias.data    # Shape: [16]
    w2 = trained_model.output.weight.data  # Shape: [10, 16]
    b2 = trained_model.output.bias.data    # Shape: [10]
    
    print("\nQuantizing and dumping parameters...")
    
    # Convert and export
    # One file per neuron, holding that neuron's incoming weights in the order
    # the column BRAM reads them.
    save_per_neuron_hex_files(w1, "hidden")
    save_per_neuron_hex_files(w2, "output")

    save_to_hex_file(float_to_fixed_hex(b1), "b1_biases.hex")
    save_to_hex_file(float_to_fixed_hex(b2), "b2_biases.hex")

    print("\nDone! Files are ready for your Verilog BRAM initialization.")
