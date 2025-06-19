#!/bin/bash

# Download Annotations Script
# Downloads Zoonomia and ENCODE cCRE data with resume capability for large files

set -euo pipefail

# Configuration
DATA_DIR="data"
LOG_FILE="download.log"
TEMP_DIR="$DATA_DIR/tmp"
PARALLEL_JOBS=2

# URLs for downloads
ZOONOMIA_BASE_URL="https://cgl.gi.ucsc.edu/data/cactus/zoonomia-2021-track-hub/hg38"
ENCODE_CCRE_URL="https://downloads.wenglab.org/Registry-V4/GRCh38-cCREs.bed"
REGULOME_URL="https://www.encodeproject.org/files/ENCFF250UJY/@@download/ENCFF250UJY.tsv"
ALPHAMISSENSE_URL="https://storage.cloud.google.com/dm_alphamissense/AlphaMissense_hg38.tsv.gz"
CATLAS_BASE_URL="https://decoder-genetics.wustl.edu/catlasv1/humanenhancer/data/cCRE_by_cell_type"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to download with resume capability
download_with_resume() {
    local url="$1"
    local output_file="$2"
    local description="$3"
    
    log "Starting download: $description"
    log "URL: $url"
    log "Output: $output_file"
    
    # Create temporary file for partial downloads
    local temp_file="$TEMP_DIR/$(basename "$output_file").tmp"
    
    # Check if partial download exists
    if [[ -f "$temp_file" ]]; then
        log "Found partial download, resuming..."
        if wget --continue --timeout=60 --tries=3 --progress=bar:force \
               --output-document="$temp_file" "$url" 2>&1 | tee -a "$LOG_FILE"; then
            mv "$temp_file" "$output_file"
            success "Downloaded: $description"
        else
            warning "Download failed, removing partial file"
            rm -f "$temp_file"
            return 1
        fi
    else
        # Fresh download
        if wget --timeout=60 --tries=3 --progress=bar:force \
               --output-document="$temp_file" "$url" 2>&1 | tee -a "$LOG_FILE"; then
            mv "$temp_file" "$output_file"
            success "Downloaded: $description"
        else
            warning "Download failed for: $description"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # Verify file was downloaded correctly
    if [[ ! -s "$output_file" ]]; then
        error "Downloaded file is empty: $output_file"
    fi
    
    # Show file size
    local file_size=$(du -h "$output_file" | cut -f1)
    log "File size: $file_size"
}

# Function to check if file exists and is not empty
file_exists_and_not_empty() {
    [[ -f "$1" && -s "$1" ]]
}

# Create directory structure
setup_directories() {
    log "Setting up directory structure..."
    
    mkdir -p "$DATA_DIR"/{zoonomia,encode,regulome,alphamissense,catlas_cCRE,tmp}
    
    # Create log file
    touch "$LOG_FILE"
    
    success "Directory structure created"
}

# Download Zoonomia data
download_zoonomia() {
    log "=== Downloading Zoonomia Conservation Data ==="
    
    local zoonomia_dir="$DATA_DIR/zoonomia"
    
    # RoCCs (Regions of Conserved Constraint)
    if file_exists_and_not_empty "$zoonomia_dir/RoCCs.bed.gz"; then
        log "RoCCs file already exists, skipping download"
    else
        download_with_resume "$ZOONOMIA_BASE_URL/RoCCs.bed.gz" \
                           "$zoonomia_dir/RoCCs.bed.gz" \
                           "Zoonomia RoCCs (Regions of Conserved Constraint)"
    fi
    
    # UCEs (Ultra-Conserved Elements)
    if file_exists_and_not_empty "$zoonomia_dir/zooUCEs.bed.gz"; then
        log "UCEs file already exists, skipping download"
    else
        download_with_resume "$ZOONOMIA_BASE_URL/zooUCEs.bed.gz" \
                           "$zoonomia_dir/zooUCEs.bed.gz" \
                           "Zoonomia UCEs (Ultra-Conserved Elements)"
    fi
    
    # UNICORNs (Ultra-Conserved Noncoding Elements)
    if file_exists_and_not_empty "$zoonomia_dir/UNICORNs.bed.gz"; then
        log "UNICORNs file already exists, skipping download"
    else
        download_with_resume "$ZOONOMIA_BASE_URL/UNICORNs.bed.gz" \
                           "$zoonomia_dir/UNICORNs.bed.gz" \
                           "Zoonomia UNICORNs (Ultra-Conserved Noncoding Elements)"
    fi
}

# Download ENCODE cCRE data
download_encode() {
    log "=== Downloading ENCODE cCRE Data ==="
    
    local encode_dir="$DATA_DIR/encode"
    local ccre_file="$encode_dir/GRCh38-cCREs.bed"
    
    if file_exists_and_not_empty "$ccre_file"; then
        log "ENCODE cCRE file already exists, skipping download"
    else
        download_with_resume "$ENCODE_CCRE_URL" \
                           "$ccre_file" \
                           "ENCODE cCREs (candidate Cis-Regulatory Elements)"
    fi
}

# Download RegulomeDB data
download_regulome() {
    log "=== Downloading RegulomeDB Data ==="
    
    local regulome_dir="$DATA_DIR/regulome"
    local regulome_file="$regulome_dir/regulomedb.tsv"
    
    if file_exists_and_not_empty "$regulome_file"; then
        log "RegulomeDB file already exists, skipping download"
    else
        download_with_resume "$REGULOME_URL" \
                           "$regulome_file" \
                           "RegulomeDB regulatory annotations"
    fi
}

# Download AlphaMissense data
download_alphamissense() {
    log "=== Downloading AlphaMissense Data ==="
    
    local alphamissense_dir="$DATA_DIR/alphamissense"
    local alphamissense_file="$alphamissense_dir/AlphaMissense_hg38.tsv.gz"
    
    if file_exists_and_not_empty "$alphamissense_file"; then
        log "AlphaMissense file already exists, skipping download"
    else
        download_with_resume "$ALPHAMISSENSE_URL" \
                           "$alphamissense_file" \
                           "AlphaMissense pathogenicity predictions"
    fi
}

# Download catlas cCRE data
download_catlas() {
    log "=== Downloading catlas cCRE Data ==="
    
    local catlas_dir="$DATA_DIR/catlas_cCRE"
    local catlas_ccre_url="https://decoder-genetics.wustl.edu/catlasv1/humanenhancer/data/cCREs"
    
    # Get list of all .bed files from the directory
    log "Getting list of available .bed files from $catlas_ccre_url"
    local bed_files
    if ! bed_files=$(wget -qO- "$catlas_ccre_url/" | grep -oP '[\w\-,]+\.bed(?=")' | sort -u); then
        error "Failed to get list of .bed files from $catlas_ccre_url"
    fi
    
    if [[ -z "$bed_files" ]]; then
        error "No .bed files found at $catlas_ccre_url"
    fi
    
    log "Found $(echo "$bed_files" | wc -l) .bed files to download"
    
    # Function to download a single bed file
    download_single_bed() {
        local bed_file="$1"
        local output_file="$catlas_dir/$bed_file"
        
        if file_exists_and_not_empty "$output_file"; then
            log "catlas $bed_file already exists, skipping download"
            return 0
        fi
        
        log "Downloading and extracting first 3 columns: $bed_file"
        local temp_file="$TEMP_DIR/$(basename "$output_file").tmp.$$"
        
        if wget --timeout=60 --tries=3 --progress=bar:force \
               --output-document=- "$catlas_ccre_url/$bed_file" 2>/dev/null | \
               cut -f1-3 > "$temp_file"; then
            mv "$temp_file" "$output_file"
            success "Downloaded and processed: $bed_file"
        else
            warning "Download failed for: $bed_file"
            rm -f "$temp_file"
            return 1
        fi
        
        # Verify file was created and is not empty
        if [[ ! -s "$output_file" ]]; then
            error "Processed file is empty: $output_file"
            return 1
        fi
        
        # Show file size
        local file_size=$(du -h "$output_file" | cut -f1)
        log "File size: $file_size"
        return 0
    }
    
    # Export function for parallel execution
    export -f download_single_bed
    export -f log
    export -f success
    export -f warning
    export -f error
    export -f file_exists_and_not_empty
    export catlas_dir
    export catlas_ccre_url
    export TEMP_DIR
    export LOG_FILE
    export BLUE
    export GREEN
    export RED
    export YELLOW
    export NC
    
    # Download bed files in parallel
    log "Downloading bed files using $PARALLEL_JOBS parallel processes"
    if command -v parallel >/dev/null 2>&1; then
        echo "$bed_files" | parallel -j "$PARALLEL_JOBS" download_single_bed {}
    else
        log "GNU parallel not found, using xargs with $PARALLEL_JOBS processes"
        echo "$bed_files" | xargs -n 1 -P "$PARALLEL_JOBS" -I {} bash -c 'download_single_bed "$@"' _ {}
    fi
}

# Verify downloads
verify_downloads() {
    log "=== Verifying Downloads ==="
    
    local files_to_check=(
        "$DATA_DIR/zoonomia/RoCCs.bed.gz"
        "$DATA_DIR/zoonomia/zooUCEs.bed.gz" 
        "$DATA_DIR/zoonomia/UNICORNs.bed.gz"
        "$DATA_DIR/encode/GRCh38-cCREs.bed"
        "$DATA_DIR/regulome/regulomedb.tsv"
        "$DATA_DIR/alphamissense/AlphaMissense_hg38.tsv.gz"
    )
    
    local all_good=true
    
    # Check standard files
    for file in "${files_to_check[@]}"; do
        if file_exists_and_not_empty "$file"; then
            local size=$(du -h "$file" | cut -f1)
            success "✓ $file ($size)"
        else
            error "✗ Missing or empty: $file"
            all_good=false
        fi
    done
    
    # Check catlas .bed files
    local catlas_dir="$DATA_DIR/catlas_cCRE"
    if [[ -d "$catlas_dir" ]]; then
        local bed_count=$(find "$catlas_dir" -name "*.bed" -type f | wc -l)
        if [[ $bed_count -gt 0 ]]; then
            success "✓ Found $bed_count catlas .bed files in $catlas_dir"
            
            # Check for any empty files
            local empty_files=$(find "$catlas_dir" -name "*.bed" -type f -empty | wc -l)
            if [[ $empty_files -gt 0 ]]; then
                warning "Found $empty_files empty .bed files in $catlas_dir"
                all_good=false
            fi
        else
            error "✗ No catlas .bed files found in $catlas_dir"
            all_good=false
        fi
    else
        error "✗ catlas directory not found: $catlas_dir"
        all_good=false
    fi
    
    if $all_good; then
        success "All downloads verified successfully!"
    else
        error "Some downloads are missing or incomplete"
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    success "Cleanup complete"
}

# Main execution
main() {
    log "Starting annotation data download script"
    log "Data directory: $DATA_DIR"
    
    # Setup
    setup_directories
    
    # Downloads
    download_zoonomia
    download_encode
    download_regulome
    download_alphamissense
    download_catlas
    
    # Verification
    verify_downloads
    
    # Cleanup
    cleanup
    
    success "Download script completed successfully!"
    log "All annotation files are now available in the '$DATA_DIR' directory"
    log "Check $LOG_FILE for detailed download information"
}

# Error handling
trap 'error "Script interrupted or failed"' ERR
trap 'cleanup' EXIT

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Downloads Zoonomia and ENCODE cCRE annotation data with resume capability.

OPTIONS:
    -h, --help       Show this help message
    -d, --data-dir   Set custom data directory (default: data)
    -l, --log-file   Set custom log file (default: download.log)
    -j, --jobs       Number of parallel jobs for catlas bed file downloads (default: 2)
    
FEATURES:
    - Automatic resume of interrupted downloads
    - Parallel downloads for catlas bed files
    - Verification of downloaded files
    - Detailed logging
    - Error handling with cleanup
    
DOWNLOADS:
    - Zoonomia RoCCs (Regions of Conserved Constraint)
    - Zoonomia UCEs (Ultra-Conserved Elements)  
    - Zoonomia UNICORNs (Ultra-Conserved Noncoding Elements)
    - ENCODE cCREs (candidate Cis-Regulatory Elements)
    - RegulomeDB regulatory annotations
    - AlphaMissense pathogenicity predictions
    - catlas cCRE data (all .bed files from cell-type specific directory)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -j|--jobs)
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                PARALLEL_JOBS="$2"
            else
                error "Invalid number of jobs: $2. Must be a positive integer."
            fi
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check dependencies
command -v wget >/dev/null 2>&1 || error "wget is required but not installed"

# Run main function
main