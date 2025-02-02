#suport for pcie 1.0-5.0

# start with wget -qO- https://machodrone.github.io/PCIeVerCheck/PCIeVerCheck.sh | bash

# OLD start with wget -qO PCIeVerCheck.sh 'https://machodrone.github.io/PCIeVerCheck/PCIeVerCheck.sh' && sudo bash PCIeVerCheck.sh && rm PCIeVerCheck.sh

#!/bin/bash
reset

# Get the current awk version
#awk_version=$(awk --version | head -n1 | awk '{print $3}')

# Get the latest available gawk version from the package manager
#latest_awk_version=$(apt-cache policy gawk | grep Candidate | awk '{print $2}')

# Display the current and latest versions
#echo "Current awk version: $awk_version"
#echo "Latest available gawk version: $latest_awk_version"

# Check if the current version is outdated
#if [ "$awk_version" != "$latest_awk_version" ]; then
    # Prompt the user to update
#    echo "Would you like to update awk to the latest version? (y/n)"
#    read answer

    # Process the user's response
#    if [ "$answer" = "y" ]; then
#        echo "Updating awk to the latest version..."
#        sudo apt update -y && sudo apt install gawk -y
#    else
#        echo "Update cancelled."
#    fi
#else
#    echo "You are already using the latest version of awk."
#fi

#sleep 1
clear
sudo bash << EOF
for i in {0..7}; do
    # Check if the GPU exists
    if nvidia-smi -i \$i &> /dev/null; then
        # Enable persistence mode
        nvidia-smi -i \$i -pm 1 &> /dev/null

        # Set GPU and memory clocks
        nvidia-smi -i \$i -lgc 500,500 &> /dev/null
        nvidia-smi -i \$i -lmc 5000 &> /dev/null

        # Query performance state
        nvidia-smi -i \$i -q -d PERFORMANCE &> /dev/null
        sleep 2

        # Extract CUDA version directly from nvidia-smi output
        cuda_version=\$(nvidia-smi -i \$i | grep "CUDA Version" | awk '{print \$9}')

        # Extract PCIe speed and width
        pcie_speed=\$(lspci -vv -s \$(nvidia-smi -i \$i --query-gpu=pci.bus_id --format=csv,noheader) | grep -i "LnkSta:" | awk -F'Speed |GT/s' '{print \$2}' | awk '{if(\$1==2.5)print "1.0";else if(\$1==5.0)print "2.0";else if(\$1==8.0)print "3.0";else if(\$1==16.0)print "4.0";else if(\$1==32.0)print "5.0";else print "Unknown"}')
        pcie_width=\$(lspci -vv -s \$(nvidia-smi -i \$i --query-gpu=pci.bus_id --format=csv,noheader) | grep -i "LnkSta:" | awk '{print \$3}' | cut -d'x' -f2 | sed 's/GT\/s,//')
        # Format pcie_width for display
        formatted_width="x\$pcie_width"
        if [ \${#pcie_width} -eq 1 ]; then
            formatted_width="x \$pcie_width"
        fi

        # Extract VRAM size
        vram_mib=\$(nvidia-smi -i \$i --query-gpu=memory.total --format=csv,noheader | awk '{print \$1}')
        vram_gb=\$(echo "\$vram_mib / 1024" | bc -l | awk '{print int(\$1 + 0.5)}')  # Round to nearest whole number

        # Extract GPU name
        gpu_name=\$(lspci -s \$(nvidia-smi -i \$i --query-gpu=pci.bus_id --format=csv,noheader) | cut -d ":" -f 3-)

        # Extract driver version and temperature
        driver_version=\$(nvidia-smi -i \$i --query-gpu=driver_version --format=csv,noheader)
        temperature=\$(nvidia-smi -i \$i --query-gpu=temperature.gpu --format=csv,noheader)

        # Output GPU details with new format
        echo "GPU PCIe \$pcie_speed \$formatted_width slot \$vram_gb GB  \$driver_version  \$cuda_version  \$temperature°C  \$gpu_name"

        # Reset GPU clocks and disable persistence mode
        nvidia-smi -i \$i -rgc &> /dev/null
        nvidia-smi -i \$i -rmc &> /dev/null
        nvidia-smi -i \$i -pm 0 &> /dev/null
    fi  # Removed the else clause for "GPU looking..."
done
EOF
echo ""
echo -e "\033[1;4;31mMemory Type and Type Detail'Unknown' is likely an empty RAM slot\033[0m"
sudo dmidecode --type memory | grep -i "type\|speed"
echo ""

sudo lspci -vvv 2>/dev/null | grep -A 30 NVMe | grep -i "LnkCap" | awk '
BEGIN {
    # Base speed for PCIe 1.0
    base_speed = 2.5;
}
{
    if ($1 == "LnkCap:") {
        for (i = 1; i <= NF; i++) {
            if ($i == "Speed") {
                speed = $(i + 1);
                gsub(/[,GT\/s]/, "", speed);
                speed = speed + 0; # Convert to number
                version = 1;
                while (speed > base_speed * (2 ^ (version - 1))) version++;
                print "Current Link Speed: " speed " GT/s (PCIe " version ".0)";
                break;
            }
        }
    }
}'
sudo lspci -vvv 2>/dev/null | grep -A 30 NVMe | grep -i "LnkCap"

# Additional checks for PCIe 1.0 to 5.0 compatibility

sudo bash << EOF

echo -e "\033[34m"
# Extract CPU model, focusing only on the first line and relevant parts, removing newlines and spaces
cpu_model=\$(lscpu | grep -i "Model name" | cut -d ':' -f2 | sed 's/^[ \t]*//;s/[ \t]*\$//' | awk '{print \$1, \$2, \$3, \$4}' | head -n 1 | tr -d '\n' | sed 's/ //g')

# Debug: Print the extracted CPU model
echo "Extracted CPU Model: \$cpu_model"

# Check for PCIe 4.0 compatibility
echo "Checking for match: \$cpu_model"
if [[ \$cpu_model =~ "Ryzen9" && \$cpu_model =~ "5900X" ]]; then
    echo "CPU Compatibility: AMD Ryzen 9 5900X supports PCIe 4.0"
else
    echo "CPU Compatibility: CPU model not recognized for PCIe 4.0 support."
fi

echo ""
# Check RAM (DDR4) support for PCIe 4.0
sudo dmidecode --type memory | awk '
BEGIN {
    slot_count = 0;
}
{
    if (/Type: DDR4/) {
        printf "Memory Type: DDR4 - Compatible with PCIe 4.0 -- ";
        speed_found = 0;
        while (getline > 0) {
            if (/Speed: ([0-9]+) MT\/s/) {
                print $2 " ";
                speed_found = 1;
                slot_count++;
                break;
            }
            if (/DMI type 17/) {
                break;  # Exit the loop if we reach the next memory slot
            }
        }
        if (!speed_found) {
            print "see above";
        }
    } else if (/DMI type 17/ && /Unknown/) {
        print "Memory Type and Type Detail: Unknown - empty?";
        slot_count++;
    }
}'
# Check NVMe SSD for PCIe 1.0 to 5.0 support
echo -e "\nNVMe SSD Check for PCIe 1.0-5.0 Compatibility:"
pci_info=\$(sudo lspci -vvv 2>/dev/null | grep -A 30 NVMe | grep -i "LnkCap")
while IFS= read -r line; do
    if [[ \$line =~ Speed[[:space:]]*([0-9]+)[[:space:]]*GT/s ]]; then
        speed=\${BASH_REMATCH[1]}
        case \$speed in
            2) echo "NVMe SSD PCIe Compatibility: Supports PCIe 1.0";;
            5) echo "NVMe SSD PCIe Compatibility: Supports PCIe 2.0";;
            8) echo "NVMe SSD PCIe Compatibility: Supports PCIe 3.0";;
            16) echo "NVMe SSD PCIe Compatibility: Supports PCIe 4.0";;
            32) echo "NVMe SSD PCIe Compatibility: Supports PCIe 5.0";;
            *) echo "NVMe SSD PCIe Compatibility: Unknown or unsupported speed";;
        esac
        break
    fi
done <<< "\$pci_info"
if [[ -z \$(echo \$pci_info | grep -E "Speed 2GT/s|Speed 5GT/s|Speed 8GT/s|Speed 16GT/s|Speed 32GT/s") ]]; then
    echo "NVMe SSD PCIe Compatibility: No PCIe 1.0-5.0 NVMe SSD detected or check manually."
fi

# Check for PCIe 1.0 to 5.0 slot for GPU
echo -e "\nGPU Slot Check for PCIe 1.0-5.0 Compatibility:"
pci_info=\$(sudo lspci -vvv 2>/dev/null | grep -A 30 "Root Port" | grep -i "LnkCap")
while IFS= read -r line; do
    if [[ \$line =~ Speed[[:space:]]*([0-9]+)[[:space:]]*GT/s ]]; then
        speed=\${BASH_REMATCH[1]}
        case \$speed in
            2) echo "GPU Slot PCIe Compatibility: PCIe 1.0 x16 slot available";;
            5) echo "GPU Slot PCIe Compatibility: PCIe 2.0 x16 slot available";;
            8) echo "GPU Slot PCIe Compatibility: PCIe 3.0 x16 slot available";;
            16) echo "GPU Slot PCIe Compatibility: PCIe 4.0 x16 slot available";;
            32) echo "GPU Slot PCIe Compatibility: PCIe 5.0 x16 slot available";;
            *) echo "GPU Slot PCIe Compatibility: Unknown or unsupported speed";;
        esac
        break
    fi
done <<< "\$pci_info"
if [[ -z \$(echo \$pci_info | grep -E "Speed 2GT/s|Speed 5GT/s|Speed 8GT/s|Speed 16GT/s|Speed 32GT/s") ]]; then
    echo "GPU Slot PCIe Compatibility: No PCIe 1.0-5.0 slot detected or check manually."
fi
sudo rm PCIEVerCheck.sh -f
EOF
