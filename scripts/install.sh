#!/bin/bash

# Nitroterm macOS/Linux Installer
# Bash script to install Nitroterm on Unix-like systems

set -e

# Configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
FORCE_INSTALL="${FORCE_INSTALL:-false}"
ADD_TO_SHELL="${ADD_TO_SHELL:-true}"
BUILD_FROM_SOURCE="${BUILD_FROM_SOURCE:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

if [[ $OSTYPE == "darwin"* ]]; then
	# macOS için
	INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
else
	# Linux için
	INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
fi

select_install_dir() {
	if [[ -n $INSTALL_DIR ]]; then
		return # Already set via command line
	fi

	log_info "📁 Select installation directory:"
	echo ""

	if [[ $OSTYPE == "darwin"* ]]; then
		# macOS options
		echo "  1. /usr/local/bin (recommended, requires sudo)"
		echo "  2. $HOME/.local/bin (user only)"
		echo "  3. $HOME/bin (user only)"
		echo "  4. Custom path"
		echo ""
		read -p "Choose option [1-4] (default: 1): " -r choice

		case "${choice:-1}" in
		1) INSTALL_DIR="/usr/local/bin" ;;
		2) INSTALL_DIR="$HOME/.local/bin" ;;
		3) INSTALL_DIR="$HOME/bin" ;;
		4)
			read -p "Enter custom path: " -r INSTALL_DIR
			;;
		*)
			log_error "Invalid choice"
			exit 1
			;;
		esac
	else
		# Linux options
		echo "  1. $HOME/.local/bin (recommended)"
		echo "  2. $HOME/bin"
		echo "  3. /usr/local/bin (system-wide, requires sudo)"
		echo "  4. Custom path"
		echo ""
		read -p "Choose option [1-4] (default: 1): " -r choice

		case "${choice:-1}" in
		1) INSTALL_DIR="$HOME/.local/bin" ;;
		2) INSTALL_DIR="$HOME/bin" ;;
		3) INSTALL_DIR="/usr/local/bin" ;;
		4)
			read -p "Enter custom path: " -r INSTALL_DIR
			;;
		*)
			log_error "Invalid choice"
			exit 1
			;;
		esac
	fi

	log_info "Selected installation directory: $INSTALL_DIR"
}

# Banner
print_banner() {
	echo -e "${CYAN}"
	cat <<"EOF"
    ███╗   ██╗██╗████████╗██████╗  ██████╗ ██╗  ██╗██╗████████╗
    ████╗  ██║██║╚══██╔══╝██╔══██╗██╔═══██╗██║ ██╔╝██║╚══██╔══╝
    ██╔██╗ ██║██║   ██║   ██████╔╝██║   ██║█████╔╝ ██║   ██║
    ██║╚██╗██║██║   ██║   ██╔══██╗██║   ██║██╔═██╗ ██║   ██║
    ██║ ╚████║██║   ██║   ██║  ██║╚██████╔╝██║  ██╗██║   ██║
    ╚═╝  ╚═══╝╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝   ╚═╝

    🚀 Nitroterm macOS/Linux Installer
    A terminal tool for project management and automation

EOF
	echo -e "${NC}"
}

# Helper functions
log_info() {
	echo -e "${BLUE}$1${NC}"
}

log_success() {
	echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
	echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
	echo -e "${RED}❌ $1${NC}"
}

# Check system requirements
check_requirements() {
	log_info "🔍 Checking system requirements..."

	# Check for Rust
	if command -v cargo >/dev/null 2>&1; then
		RUST_VERSION=$(cargo --version)
		log_success "Rust found: $RUST_VERSION"
	else
		log_warning "Rust not found. Installing Rust..."
		install_rust
	fi

	# Check for Git
	if command -v git >/dev/null 2>&1; then
		GIT_VERSION=$(git --version)
		log_success "Git found: $GIT_VERSION"
	else
		log_warning "Git not found. Please install Git:"
		echo "  • macOS: brew install git or from https://git-scm.com/"
		echo "  • Ubuntu/Debian: sudo apt install git"
		echo "  • CentOS/RHEL: sudo yum install git"
		echo ""
		read -p "Continue without Git? (some features may not work) [y/N]: " -r
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			exit 1
		fi
	fi
}

# Install Rust
install_rust() {
	log_info "📥 Downloading Rust installer..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

	# Source the cargo environment
	source "$HOME/.cargo/env"

	log_success "Rust installation completed!"
}

# Create installation directory
create_install_dir() {
	log_info "📁 Creating installation directory: $INSTALL_DIR"

	if [[ -d $INSTALL_DIR ]] && [[ $FORCE_INSTALL != "true" ]]; then
		read -p "Installation directory already exists. Continue? [y/N]: " -r
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			log_error "Installation cancelled."
			exit 1
		fi
	fi

	mkdir -p "$INSTALL_DIR"
	log_success "Installation directory created!"
}

install_nitroterm() {
	local nitroterm_binary="$INSTALL_DIR/nitroterm"
	local requires_sudo=false

	# Check if we need sudo
	if [[ $INSTALL_DIR == "/usr/local/bin" ]] || [[ $INSTALL_DIR == "/usr/bin" ]]; then
		requires_sudo=true
	fi

	log_info "🏗️  Building Nitroterm from source..."
	log_info "Target binary location: $nitroterm_binary"

	# Check if we're already in the nitroterm directory
	if [[ -f "Cargo.toml" ]] && grep -q "nitroterm" Cargo.toml 2>/dev/null; then
		log_info "🎯 Using current directory (local development)"
		local work_dir="$(pwd)"
	else
		# Try to clone from GitHub
		local temp_dir=$(mktemp -d)
		log_info "Temp directory: $temp_dir"
		cd "$temp_dir"

		log_info "📥 Cloning repository..."
		if git clone https://github.com/mustafagenc/nitroterm.git 2>/dev/null; then
			log_success "Repository cloned successfully"
			cd nitroterm
			local work_dir="$(pwd)"
		else
			log_error "❌ Failed to clone repository!"
			log_error "Repository might not exist or be private."
			log_error ""
			log_error "Solutions:"
			log_error "1. Make sure the repository exists at: https://github.com/mustafagenc/nitroterm"
			log_error "2. Run this script from the nitroterm project directory"
			log_error "3. Push your code to GitHub first"
			rm -rf "$temp_dir"
			exit 1
		fi
	fi

	# Check if Cargo.toml exists
	if [[ -f "Cargo.toml" ]]; then
		log_success "Found Cargo.toml"
	else
		log_error "Cargo.toml not found!"
		exit 1
	fi

	log_info "🔨 Compiling Nitroterm..."
	if cargo build --release; then
		log_success "Build completed successfully!"
	else
		log_error "Build failed!"
		exit 1
	fi

	# Check if binary was created
	if [[ -f "target/release/nitroterm" ]]; then
		log_success "Binary found at target/release/nitroterm"
	else
		log_error "Binary not found!"
		exit 1
	fi

	# Install binary with proper permissions
	log_info "📦 Installing binary to $nitroterm_binary..."

	if [[ $requires_sudo == "true" ]]; then
		log_info "Installing to system directory requires administrator privileges..."
		if sudo cp target/release/nitroterm "$nitroterm_binary" && sudo chmod +x "$nitroterm_binary"; then
			log_success "Binary installed successfully with sudo"
		else
			log_error "Failed to install binary with sudo"
			exit 1
		fi
	else
		if cp target/release/nitroterm "$nitroterm_binary" && chmod +x "$nitroterm_binary"; then
			log_success "Binary installed successfully"
		else
			log_error "Failed to install binary"
			exit 1
		fi
	fi

	# Cleanup only if we used temp directory
	if [[ $work_dir == *"/tmp/"* ]]; then
		rm -rf "$(dirname "$work_dir")"
	fi

	# Test the binary
	log_info "Testing binary..."
	if "$nitroterm_binary" --version >/dev/null 2>&1; then
		log_success "Binary test successful!"
	else
		log_warning "Binary test failed, but installation completed"
	fi
}

# Add to shell PATH
add_to_path() {
	if [[ $ADD_TO_SHELL != "true" ]]; then
		return
	fi

	log_info "🔧 Adding Nitroterm to PATH..."

	# Detect shell
	local shell_name=$(basename "$SHELL")
	local shell_rc=""

	case "$shell_name" in
	bash)
		if [[ $OSTYPE == "darwin"* ]]; then
			shell_rc="$HOME/.bash_profile"
		else
			shell_rc="$HOME/.bashrc"
		fi
		;;
	zsh)
		shell_rc="$HOME/.zshrc"
		;;
	fish)
		shell_rc="$HOME/.config/fish/config.fish"
		;;
	*)
		log_warning "Unknown shell: $shell_name. Please manually add $INSTALL_DIR to your PATH."
		return
		;;
	esac

	# Check if already in PATH
	if echo "$PATH" | grep -q "$INSTALL_DIR"; then
		log_success "Already in PATH!"
		return
	fi

	# Add to shell configuration
	if [[ $shell_name == "fish" ]]; then
		echo "set -gx PATH $INSTALL_DIR \$PATH" >>"$shell_rc"
	else
		echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >>"$shell_rc"
	fi

	log_success "Added to PATH! (restart your terminal or run 'source $shell_rc')"
}

# Create alias for easy access
create_alias() {
	log_info "🔗 Creating helpful aliases..."

	local shell_name=$(basename "$SHELL")
	local shell_rc=""

	case "$shell_name" in
	bash)
		if [[ $OSTYPE == "darwin"* ]]; then
			shell_rc="$HOME/.bash_profile"
		else
			shell_rc="$HOME/.bashrc"
		fi
		;;
	zsh)
		shell_rc="$HOME/.zshrc"
		;;
	fish)
		shell_rc="$HOME/.config/fish/config.fish"
		;;
	esac

	if [[ -n $shell_rc ]]; then
		if [[ $shell_name == "fish" ]]; then
			echo "alias nk='nitroterm'" >>"$shell_rc"
			echo "alias nki='nitroterm -i'" >>"$shell_rc"
		else
			echo "alias nk='nitroterm'" >>"$shell_rc"
			echo "alias nki='nitroterm -i'" >>"$shell_rc"
		fi

		log_success "Aliases created! Use 'nk' or 'nki' for quick access."
	fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--install-dir)
		INSTALL_DIR="$2"
		shift 2
		;;
	--force)
		FORCE_INSTALL="true"
		shift
		;;
	--no-path)
		ADD_TO_SHELL="false"
		shift
		;;
	--download-binary)
		BUILD_FROM_SOURCE="false"
		shift
		;;
	--help)
		echo "Nitroterm Installer"
		echo ""
		echo "Options:"
		echo '  --install-dir DIR     Installation directory (default: $HOME/.local/bin)'
		echo "  --force              Force installation"
		echo "  --no-path            Don't add to PATH"
		echo "  --download-binary    Download pre-built binary instead of building"
		echo "  --help               Show this help"
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		exit 1
		;;
	esac
done

# Main installation process
main() {
	print_banner

	log_info "Starting Nitroterm installation..."
	log_info "Installation directory: $INSTALL_DIR"
	echo ""

	check_requirements
	create_install_dir
	install_nitroterm
	add_to_path
	create_alias

	echo ""
	echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
	echo ""
	echo -e "${CYAN}📍 Installation location:${NC} $INSTALL_DIR"
	echo -e "${CYAN}🚀 Usage:${NC}"
	echo "   • Command line: nitroterm"
	echo "   • Interactive mode: nitroterm -i"
	echo "   • Quick aliases: nk, nki"
	echo "   • Generate release notes: nitroterm release-notes"
	echo "   • Update dependencies: nitroterm update-dependencies"
	echo ""
	echo -e "${CYAN}📚 Documentation:${NC} https://github.com/mustafagenc/nitroterm"
	echo -e "${CYAN}🐛 Issues:${NC} https://github.com/mustafagenc/nitroterm-/issues"
	echo ""

	if [[ $ADD_TO_SHELL == "true" ]]; then
		echo -e "${YELLOW}💡 Don't forget to restart your terminal or run 'source ~/.bashrc' (or equivalent)${NC}"
		echo ""
	fi
}

# Run main function
main "$@"
