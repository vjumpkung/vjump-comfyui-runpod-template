#!/bin/bash

# NVIDIA GPU Information Display Script
# Beautiful output with colors and formatting

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ASCII symbols
GPU_ICON="[GPU]"
CUDA_ICON="[CUDA]"
CHECK_MARK="[OK]"
CROSS_MARK="[ERROR]"
SEPARATOR="="

# Function to print a fancy header
print_header() {
    local title="$1"
    local width=50
    echo -e "\n${CYAN}$(printf "%*s" $width | tr ' ' $SEPARATOR)${NC}"
    echo -e "${WHITE}${BOLD}$(printf "%*s" $(((width + ${#title}) / 2)) "$title")${NC}"
    echo -e "${CYAN}$(printf "%*s" $width | tr ' ' $SEPARATOR)${NC}\n"
}

# Function to print formatted info
print_info() {
    local icon="$1"
    local label="$2"
    local value="$3"
    local color="$4"
    printf "${icon} ${BOLD}${label}:${NC} ${color}%s${NC}\n" "$value"
}

# Function to check if nvidia-smi is available
check_nvidia_smi() {
    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "${CROSS_MARK} ${RED}nvidia-smi not found. Please install NVIDIA drivers.${NC}"
        exit 1
    fi
}

# Function to extract GPU names
get_gpu_names() {
    nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null
}

# Function to extract CUDA version
get_cuda_version() {
    nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1
    # Alternative method for CUDA version from nvidia-smi output
    local cuda_version=$(nvidia-smi 2>/dev/null | grep -oP "CUDA Version: \K[0-9]+\.[0-9]+")
    if [[ -n "$cuda_version" ]]; then
        echo "$cuda_version"
    else
        echo "N/A"
    fi
}

# Function to get driver version
get_driver_version() {
    nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1
}

# Function to get GPU count
get_gpu_count() {
    nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | wc -l
}

# Main execution
main() {
    # Check if nvidia-smi is available
    check_nvidia_smi

    # Print header
    print_header "NVIDIA GPU INFORMATION"

    # Get GPU information
    local gpu_names=$(get_gpu_names)
    local cuda_version=$(get_cuda_version)
    local driver_version=$(get_driver_version)
    local gpu_count=$(get_gpu_count)

    # Check if we got valid data
    if [[ -z "$gpu_names" ]]; then
        echo -e "${CROSS_MARK} ${RED}No NVIDIA GPUs detected or nvidia-smi failed.${NC}"
        exit 1
    fi

    # Display GPU count
    print_info "[COUNT]" "GPU Count" "$gpu_count" "$GREEN"
    echo

    # Display each GPU
    local counter=1
    while IFS= read -r gpu_name; do
        if [[ -n "$gpu_name" ]]; then
            print_info "$GPU_ICON" "GPU $counter" "$gpu_name" "$YELLOW"
            ((counter++))
        fi
    done <<<"$gpu_names"

    echo

    # Display CUDA version
    if [[ "$cuda_version" != "N/A" ]]; then
        print_info "$CUDA_ICON" "CUDA Version" "$cuda_version" "$MAGENTA"
    else
        print_info "$CUDA_ICON" "CUDA Version" "Not Available" "$RED"
    fi

    # Display driver version
    if [[ -n "$driver_version" ]]; then
        print_info "[DRIVER]" "Driver Version" "$driver_version" "$BLUE"
    fi

    # Success message
    echo
    echo -e "${CHECK_MARK} ${GREEN}GPU information retrieved successfully!${NC}"

    # Optional: Show brief nvidia-smi summary
    if [[ "$1" == "--full" ]] || [[ "$1" == "-f" ]]; then
        echo
        print_header "NVIDIA-SMI OUTPUT"
        nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=table
    fi

    echo
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -f, --full    Show additional nvidia-smi table output"
    echo
    echo "Examples:"
    echo "  $0              # Basic GPU info"
    echo "  $0 --full       # GPU info with detailed table"
}

# Parse command line arguments
case "$1" in
-h | --help)
    show_help
    exit 0
    ;;
-f | --full)
    main --full
    ;;
"")
    main
    ;;
*)
    echo -e "${RED}Unknown option: $1${NC}"
    show_help
    exit 1
    ;;
esac
