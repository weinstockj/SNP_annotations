#!/bin/bash

# check_requirements.sh - Verify and install project requirements using uv
# This script checks for required tools and Python dependencies for the SNP annotations project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_status $BLUE "=== SNP Annotations Project Requirements Check ==="

# Check if we're in the correct directory
if [[ ! -f "pyproject.toml" ]] || [[ ! -f "uv.lock" ]]; then
    print_status $RED "Error: This script must be run from the project root directory (where pyproject.toml and uv.lock exist)"
    exit 1
fi

# Check for uv installation
print_status $BLUE "Checking for uv..."
if ! command -v uv &> /dev/null; then
    print_status $RED "uv is not installed. Please install uv first:"
    print_status $YELLOW "curl -LsSf https://astral.sh/uv/install.sh | sh"
    print_status $YELLOW "or visit: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
else
    UV_VERSION=$(uv --version)
    print_status $GREEN "✓ uv found: $UV_VERSION"
fi

# Check Python version requirement
print_status $BLUE "Checking Python version requirement..."
REQUIRED_PYTHON=$(grep "requires-python" pyproject.toml | sed 's/.*>=\([0-9.]*\).*/\1/')
if [[ -n "$REQUIRED_PYTHON" ]]; then
    print_status $GREEN "✓ Project requires Python >= $REQUIRED_PYTHON"
else
    print_status $YELLOW "⚠ Could not determine Python version requirement from pyproject.toml"
fi

# Check if virtual environment exists and is synced
print_status $BLUE "Checking virtual environment..."
if uv venv --help &> /dev/null; then
    # Check if .venv exists
    if [[ -d ".venv" ]]; then
        print_status $GREEN "✓ Virtual environment found at .venv"
        
        # Check if environment is synced with uv.lock
        print_status $BLUE "Checking if environment is synced..."
        if uv sync --check &> /dev/null; then
            print_status $GREEN "✓ Virtual environment is synced with uv.lock"
        else
            print_status $YELLOW "⚠ Virtual environment needs to be synced"
            print_status $BLUE "Syncing virtual environment..."
            uv sync
            print_status $GREEN "✓ Virtual environment synced"
        fi
    else
        print_status $YELLOW "⚠ No virtual environment found"
        print_status $BLUE "Creating and syncing virtual environment..."
        uv sync
        print_status $GREEN "✓ Virtual environment created and synced"
    fi
else
    print_status $RED "Error: uv venv command not available"
    exit 1
fi

# Verify key dependencies are available
print_status $BLUE "Verifying key dependencies..."
DEPENDENCIES=("pandas" "pyarrow" "snakemake" "polars" "duckdb")

# Activate virtual environment and check imports
for dep in "${DEPENDENCIES[@]}"; do
    if uv run python -c "import $dep" &> /dev/null; then
        # Get version if possible
        VERSION=$(uv run python -c "import $dep; print(getattr($dep, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        print_status $GREEN "✓ $dep ($VERSION)"
    else
        print_status $RED "✗ Failed to import $dep"
        MISSING_DEPS=true
    fi
done

if [[ "$MISSING_DEPS" == "true" ]]; then
    print_status $RED "Some dependencies are missing. Try running: uv sync"
    exit 1
fi

# Check for additional system dependencies that might be needed
print_status $BLUE "Checking system dependencies..."

# Check for common tools that might be needed
SYSTEM_TOOLS=("git")
for tool in "${SYSTEM_TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        print_status $GREEN "✓ $tool available"
    else
        print_status $YELLOW "⚠ $tool not found (may be needed)"
    fi
done

# Check if Snakemake can be executed
print_status $BLUE "Testing Snakemake execution..."
if uv run snakemake --version &> /dev/null; then
    SNAKEMAKE_VERSION=$(uv run snakemake --version)
    print_status $GREEN "✓ Snakemake executable: $SNAKEMAKE_VERSION"
else
    print_status $RED "✗ Snakemake execution failed"
    exit 1
fi

# Check if config template exists
if [[ -f "config.template.yaml" ]]; then
    print_status $GREEN "✓ Configuration template found"
    if [[ ! -f "config.yaml" ]]; then
        print_status $YELLOW "⚠ No config.yaml found. You may need to copy from config.template.yaml"
    fi
else
    print_status $YELLOW "⚠ No config.template.yaml found"
fi

# Summary
print_status $GREEN "=== Requirements Check Complete ==="
print_status $GREEN "✓ All requirements satisfied!"
print_status $BLUE "To activate the environment manually, run: source .venv/bin/activate"
print_status $BLUE "To run commands in the environment, use: uv run <command>"
print_status $BLUE "To add new dependencies, use: uv add <package>"