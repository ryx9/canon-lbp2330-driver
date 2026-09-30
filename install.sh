#!/usr/bin/env bash
# =============================================================================
# Canon LBP2330 — Complete Driver Installer
# Supports: Arch/Manjaro (pacman), Debian/Ubuntu (apt), Fedora/RHEL (dnf)
# =============================================================================
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RESET}"; }

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  err "Please run as root:  sudo bash $0"
  exit 1
fi

# ── Detect distro / package manager ──────────────────────────────────────────
header "Detecting OS"

detect_os() {
  if command -v pacman &>/dev/null; then
    PM="pacman"
  elif command -v apt-get &>/dev/null; then
    PM="apt"
  elif command -v dnf &>/dev/null; then
    PM="dnf"
  elif command -v yum &>/dev/null; then
    PM="yum"
  else
    err "Unsupported package manager. Install deps manually and re-run."
    exit 1
  fi
  info "Package manager: ${BOLD}$PM${RESET}"
}
detect_os

# ── Package lists per distro ──────────────────────────────────────────────────
install_deps() {
  header "Installing dependencies"
  case "$PM" in

    pacman)
      # foomatic-rip is part of foomatic-db-engine on Arch
      PKGS=(
        cups
        cups-filters
        ghostscript
        foomatic-db
        foomatic-db-engine
        foomatic-db-nonfree
        foomatic-db-nonfree-ppds
        gsfonts
        a2ps
      )
      info "Syncing package database..."
      pacman -Sy --noconfirm
      info "Installing: ${PKGS[*]}"
      pacman -S --noconfirm --needed "${PKGS[@]}"
      ;;

    apt)
      PKGS=(
        cups
        cups-filters
        ghostscript
        foomatic-db
        foomatic-db-engine
        foomatic-filters
        printer-driver-gutenprint
        gsfonts
        a2ps
        libcups2
      )
      info "Updating apt cache..."
      apt-get update -qq
      info "Installing: ${PKGS[*]}"
      DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
      ;;

    dnf|yum)
      PKGS=(
        cups
        cups-filters
        ghostscript
        foomatic
        foomatic-db
        foomatic-db-ppds
        foomatic-filters
        gsfonts
        a2ps
      )
      info "Installing: ${PKGS[*]}"
      $PM install -y "${PKGS[@]}"
      ;;
  esac
  ok "Dependencies installed."
}
install_deps

# ── Verify critical binaries ──────────────────────────────────────────────────
header "Verifying binaries"
MISSING=()
for bin in gs foomatic-rip cupsd lpadmin; do
  if command -v "$bin" &>/dev/null; then
    ok "$bin → $(command -v $bin)"
  else
    warn "$bin not found in PATH"
    MISSING+=("$bin")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "Missing binaries: ${MISSING[*]}"
  err "Installation may have failed. Aborting."
  exit 1
fi

# ── Write PPD file ────────────────────────────────────────────────────────────
header "Writing PPD file"
PPD_DIR="/usr/share/cups/model"
PPD_PATH="$PPD_DIR/canon-lbp2330.ppd"
mkdir -p "$PPD_DIR"

cat > "$PPD_PATH" << 'PPD'
*PPD-Adobe: "4.3"
*% Fixed PPD for Canon LBP2330 (PCL5e)
*% Fixes: foomatic-rip filter, ljet4d→ljet4, -dFIXEDMEDIA, no -dPDFFitPage
*FormatVersion: "4.3"
*FileVersion: "1.9"
*LanguageVersion: English
*LanguageEncoding: ISOLatin1
*PCFileName: "LBP2330.PPD"
*Manufacturer: "Canon"
*Product: "(LBP2330)"
*ModelName: "Canon LBP2330 PCL5e Tray 1"
*ShortNickName: "Canon LBP2330"
*NickName: "Canon LBP2330 (PCL5e, Strict A4, Tray 1)"
*PSVersion: "(3010.000) 0"
*LanguageLevel: "3"
*ColorDevice: False
*DefaultColorSpace: Gray
*FileSystem: False
*Throughput: "30"
*LandscapeOrientation: Plus90
*VariablePaperSize: False
*TTRasterizer: Type42

*cupsFilter: "application/vnd.cups-postscript 0 foomatic-rip"

*FoomaticRIPCommandLine: "gs -q -dQUIET -dSAFER -dNOPAUSE -dBATCH -dFIXEDMEDIA -sDEVICE=ljet4 -sPAPERSIZE=a4 -dMediaPosition=1 -sOutputFile=- -"

*OpenGroup: General/General

*OpenUI *PageSize/Media Size: PickOne
*OrderDependency: 10 AnySetup *PageSize
*DefaultPageSize: A4
*PageSize A4/A4: "<</PageSize[595 842]>>setpagedevice"
*CloseUI: *PageSize

*OpenUI *PageRegion/Media Region: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: A4
*PageRegion A4/A4: "<</PageSize[595 842]>>setpagedevice"
*CloseUI: *PageRegion

*DefaultImageableArea: A4
*ImageableArea A4/A4: "12 12 583 830"
*DefaultPaperDimension: A4
*PaperDimension A4/A4: "595 842"

*OpenUI *Duplex/Double-Sided Printing: PickOne
*OrderDependency: 30 AnySetup *Duplex
*DefaultDuplex: None
*Duplex None/Off: "<</Duplex false>>setpagedevice"
*Duplex DuplexNoTumble/Long Edge (Standard): "<</Duplex true/Tumble false>>setpagedevice"
*Duplex DuplexTumble/Short Edge (Flip): "<</Duplex true/Tumble true>>setpagedevice"
*CloseUI: *Duplex

*CloseGroup: General
PPD

chmod 644 "$PPD_PATH"
ok "PPD written to $PPD_PATH"

# ── Enable & start CUPS ───────────────────────────────────────────────────────
header "Starting CUPS"
systemctl enable cups --now
sleep 1
if systemctl is-active --quiet cups; then
  ok "CUPS is running."
else
  err "CUPS failed to start. Check: journalctl -u cups"
  exit 1
fi

# ── Detect printer URI ────────────────────────────────────────────────────────
header "Detecting printer URI"
info "Scanning for Canon LBP2330..."

# Give lpinfo a moment after cups start
sleep 1
PRINTER_URI=$(lpinfo -v 2>/dev/null \
  | grep -i "canon\|lbp\|2330" \
  | awk '{print $2}' \
  | head -1 || true)

if [[ -z "$PRINTER_URI" ]]; then
  warn "Printer not auto-detected. Trying usb:// scan..."
  PRINTER_URI=$(lpinfo -v 2>/dev/null \
    | grep "^direct usb" \
    | awk '{print $2}' \
    | head -1 || true)
fi

if [[ -z "$PRINTER_URI" ]]; then
  warn "Could not auto-detect printer URI."
  warn "Is the printer plugged in and powered on?"
  echo
  info "Available URIs on this system:"
  lpinfo -v 2>/dev/null || true
  echo
  read -rp "$(echo -e "${YELLOW}Enter printer URI manually (e.g. usb://Canon/LBP2330?serial=XXX):${RESET} ")" PRINTER_URI
  if [[ -z "$PRINTER_URI" ]]; then
    err "No URI provided. Cannot register printer."
    exit 1
  fi
fi

ok "Using URI: $PRINTER_URI"

# ── Remove existing queue if present ─────────────────────────────────────────
header "Registering printer"
QUEUE_NAME="Canon-LBP2330"

if lpstat -p "$QUEUE_NAME" &>/dev/null 2>&1; then
  info "Removing existing queue '$QUEUE_NAME'..."
  lpadmin -x "$QUEUE_NAME"
fi

# ── Add printer ───────────────────────────────────────────────────────────────
info "Adding printer queue '$QUEUE_NAME'..."
lpadmin \
  -p "$QUEUE_NAME" \
  -E \
  -v "$PRINTER_URI" \
  -P "$PPD_PATH" \
  -D "Canon LBP2330" \
  -L "Local USB"

# Set as default paper size A4
lpadmin -p "$QUEUE_NAME" -o media=A4
lpadmin -p "$QUEUE_NAME" -o PageSize=A4

# Set as system default printer
lpadmin -d "$QUEUE_NAME"
ok "Printer '$QUEUE_NAME' registered and set as default."

# ── Enable & accept jobs ──────────────────────────────────────────────────────
cupsenable "$QUEUE_NAME"
cupsaccept "$QUEUE_NAME"
ok "Printer enabled and accepting jobs."

# ── Final status ──────────────────────────────────────────────────────────────
header "Installation complete"
echo
lpstat -p "$QUEUE_NAME" -l 2>/dev/null || lpstat -p "$QUEUE_NAME"
echo
ok "Done! Test print with:"
echo -e "   ${BOLD}echo 'Test Page' | lp -d $QUEUE_NAME${RESET}"
echo -e "   ${BOLD}lp -d $QUEUE_NAME /path/to/file.pdf${RESET}"
echo
