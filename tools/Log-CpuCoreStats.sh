#!/bin/bash

# Get the hostname (without FQDN)
HOSTNAME_SHORT=$(hostname -s)

# Set the output file name
OUTPUT_FILE="cpustats_${HOSTNAME_SHORT}.log"

# --- Function to check if mpstat is installed and prompt for installation ---
check_mpstat() {
    if ! command -v mpstat &> /dev/null; then
        echo "Error: mpstat command not found."
        echo "mpstat is usually part of the 'sysstat' package."

        # Determine OS distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_ID=$ID
            OS_ID_LIKE=$ID_LIKE
        else
            OS_ID=""
            OS_ID_LIKE=""
        fi

        case "$OS_ID" in
            opensuse-leap|sles)
                echo "On openSUSE/SLES, you can install it with: sudo zypper install sysstat"
                ;;
            rhel|centos|fedora|almalinux|rocky)
                echo "On RHEL, CentOS, Fedora, AlmaLinux, or Rocky Linux, you can install it with: sudo dnf install sysstat"
                ;;
            debian|ubuntu)
                echo "On Debian or Ubuntu, you can install it with: sudo apt install sysstat"
                ;;
            *)
                # Fallback for other distributions or if os-release is not fully descriptive
                if [[ "$OS_ID_LIKE" == *"suse"* ]]; then
                     echo "On openSUSE/SLES-like systems, you can install it with: sudo zypper install sysstat"
                elif [[ "$OS_ID_LIKE" == *"rhel"* || "$OS_ID_LIKE" == *"fedora"* ]]; then
                     echo "On RHEL-like systems (Alma, Rocky, CentOS), you can install it with: sudo dnf install sysstat"
                elif [[ "$OS_ID_LIKE" == *"debian"* ]]; then
                     echo "On Debian/Ubuntu-like systems, you can install it with: sudo apt install sysstat"
                else
                    echo "Please install mpstat, which is usually included in the 'sysstat' package for your distribution."
                fi
                ;;
        esac
        exit 1
    fi
}

# --- Main script execution ---

# Check for mpstat before proceeding
check_mpstat

echo "Logging CPU utilization to $OUTPUT_FILE. Press Ctrl+C to stop."
echo "Output file: $OUTPUT_FILE"

while true; do
    # Get the current timestamp in UTC
    TIMESTAMP_UTC=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # Use mpstat to get per-CPU utilization.
    # -P ALL: reports for all processors.
    # 1 1: samples 1 time with 1 second interval (this is effectively a snapshot).
    # The output is then formatted and appended to the file. The lines with Average usage are removed since it should be the same.
    echo "--- $TIMESTAMP_UTC ---" >> "$OUTPUT_FILE"
    mpstat -P ALL 1 1 | tail -n +4 | grep -v '^Average:' >> "$OUTPUT_FILE"

    # Wait for 1 second before the next capture
    sleep 1
done
