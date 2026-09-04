# Canon LBP2330 – Custom Linux/CUPS Driver

A complete, hand-crafted CUPS driver for the **Canon i-SENSYS LBP2330** that:

- Targets **PCL6 (PCL XL)** — the printer's native high-speed language
- Defaults to **A4 / Plain Paper / 600 dpi / Simplex**
- Exposes **full duplex** (long-edge and short-edge)
- Provides a **universal print wrapper** for PDF, Office formats, and images
- Does **not** impose artificial speed caps from generic/buggy drivers

---

## What's Included

```
canon-lbp2330-driver/
├── ppd/
│   └── Canon-LBP2330.ppd       ← CUPS printer description (PCL6)
├── filters/
│   └── rastertopcl6            ← Python3 PCL6 raster filter
├── scripts/
│   ├── install.sh              ← Automated installer
│   └── print-file.sh           ← Universal print wrapper
└── README.md
```

---

## Step 1 — Install Dependencies

```bash
# Debian / Ubuntu / Linux Mint
sudo apt update
sudo apt install cups cups-filters ghostscript python3 \
                 poppler-utils imagemagick libreoffice \
                 librsvg2-bin enscript

# Fedora / RHEL
sudo dnf install cups cups-filters ghostscript python3 \
                 poppler-utils ImageMagick libreoffice librsvg2-tools enscript

# Arch / Manjaro
sudo pacman -S cups cups-filters ghostscript python \
               poppler imagemagick libreoffice-still librsvg enscript
```

---

## Step 2 — Connect Your Printer

**USB (most common):**  
Just plug in the USB cable. The printer will appear as a USB device.

**Network (Ethernet or Wi-Fi):**  
Find the printer's IP address from its LCD panel:
`Menu → Network Settings → TCP/IP → IPv4 Address`

---

## Step 3 — Install the Driver

```bash
cd canon-lbp2330-driver

# USB connection:
sudo bash scripts/install.sh --usb

# Network connection (replace with your printer's IP):
sudo bash scripts/install.sh --network 192.168.1.100

# LPD/LPR protocol (older network setup):
sudo bash scripts/install.sh --lpd 192.168.1.100
```

The installer will:
1. Install the PCL6 filter to `/usr/lib/cups/filter/`
2. Install the PPD to `/usr/share/ppd/Canon/`
3. Auto-detect your USB URI or use the provided IP
4. Register the printer in CUPS with the correct defaults
5. Set it as your system default printer

---

## Step 4 — Print Something

### Graphical apps (GNOME, KDE, etc.)
The printer will appear as **"Canon i-SENSYS LBP2330"** in any print dialog.

### Command line — quick print
```bash
# Print a PDF
lp -d Canon_LBP2330 document.pdf

# Print duplex (flip on long edge — normal portrait duplex)
lp -d Canon_LBP2330 -o Duplex=DuplexNoTumble document.pdf

# Print duplex (flip on short edge — landscape/booklet style)
lp -d Canon_LBP2330 -o Duplex=DuplexTumble document.pdf

# Fine mode (1200 dpi — slower but sharper)
lp -d Canon_LBP2330 -o Resolution=1200dpi document.pdf

# Multiple copies
lp -d Canon_LBP2330 -n 3 document.pdf

# Legal paper
lp -d Canon_LBP2330 -o PageSize=Legal document.pdf
```

### Universal wrapper — any file type
```bash
# Make executable once:
chmod +x scripts/print-file.sh

# Print PDF
./scripts/print-file.sh document.pdf

# Print Word document
./scripts/print-file.sh report.docx

# Print Excel spreadsheet
./scripts/print-file.sh budget.xlsx

# Print image
./scripts/print-file.sh photo.jpg

# Print duplex, A4, fine quality
./scripts/print-file.sh -d long -q fine presentation.pptx

# Print multiple files
./scripts/print-file.sh -n 2 -d long doc1.pdf doc2.docx image.png

# Full options
./scripts/print-file.sh -h
```

#### Wrapper options
| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `-p` | printer name | `Canon_LBP2330` | Target printer |
| `-n` | 1, 2, … | `1` | Number of copies |
| `-s` | `a4`, `letter`, `legal` | `a4` | Paper size |
| `-d` | `none`, `long`, `short` | `none` | Duplex mode |
| `-q` | `normal`, `fine` | `normal` | Print quality |
| `-t` | `plain`, `thin`, `heavy` | `plain` | Media type |
| `-r` | — | — | Reverse page order |

---

## PPD Options Reference

These can be set via `lp -o` or in any application's print dialog.

| Option | Values | Default |
|--------|--------|---------|
| `PageSize` | `A4`, `Letter`, `Legal` | `A4` |
| `InputSlot` | `Cassette`, `Manual` | `Cassette` |
| `MediaType` | `Plain`, `Thin`, `Heavy` | `Plain` |
| `Resolution` | `600dpi`, `1200dpi` | `600dpi` |
| `Duplex` | `None`, `DuplexNoTumble`, `DuplexTumble` | `None` |

> **Note:** Heavy paper + duplex is blocked (hardware constraint — duplex unit
> can jam with paper above ~90 g/m²). The PPD enforces this via UIConstraints.

---

## Changing Defaults Permanently

```bash
# Set duplex as permanent default
lpoptions -p Canon_LBP2330 -o Duplex=DuplexNoTumble

# Revert to simplex
lpoptions -p Canon_LBP2330 -o Duplex=None

# Set 1200dpi as default
lpoptions -p Canon_LBP2330 -o Resolution=1200dpi
```

---

## Troubleshooting

### Printer not detected via USB
```bash
# List all detected printers
lpinfo -v

# Find your Canon and note the URI
lpinfo -v | grep -i canon

# Re-add with the correct URI
sudo lpadmin -p Canon_LBP2330 \
    -v "usb://Canon/LBP2330?serial=XXXX" \
    -P /usr/share/ppd/Canon/Canon-LBP2330.ppd -E
```

### CUPS won't start
```bash
sudo systemctl status cups
sudo journalctl -u cups -n 50
```

### Filter errors in log
```bash
sudo tail -f /var/log/cups/error_log
```

### Test filter directly
```bash
gs -dBATCH -dNOPAUSE -sDEVICE=cups -sOutputFile=test.raster test.pdf
python3 filters/rastertopcl6 1 user title 1 "" test.raster | xxd | head
```

### Jobs stuck in queue
```bash
lpq -P Canon_LBP2330
cancel -a Canon_LBP2330
```

---

## How It Works

```
Your file (PDF/DOCX/JPG…)
        │
        ▼ (CUPS dispatch)
  pdftoraster / imagetoraster
        │  [CUPS raster stream]
        ▼
  rastertopcl6   ← our custom filter
        │  [PCL6 XL binary stream]
        ▼
  usb:// or socket://
        │
        ▼
  Canon LBP2330 engine
```

**Why PCL6 and not UFR II?**  
UFR II (Canon's proprietary language) requires closed-source binary blobs that
Canon does not provide for all kernel/glibc versions, and the existing open
wrappers throttle throughput. PCL6 is an open, well-documented standard that
maps 1-to-1 to what the LBP2330 engine expects natively — no translation
overhead, no speed penalty.

**Why not use `hpijs` / generic HP PCL driver?**  
Generic PCL5 drivers don't negotiate full-speed PCL6 XL framing.
The LBP2330 accepts PCL6 XL natively; our filter speaks it directly.

---

## Supported File Formats (via `print-file.sh`)

| Format | Tool used |
|--------|-----------|
| PDF | `lp` (native CUPS) |
| DOCX, DOC, ODT, RTF | LibreOffice headless |
| XLSX, XLS, ODS, CSV | LibreOffice headless |
| PPTX, PPT, ODP | LibreOffice headless |
| JPG, PNG, TIFF, BMP, WebP | ImageMagick `convert` |
| SVG | `rsvg-convert` or Inkscape |
| TXT, MD, LOG | `enscript` → PDF |
| PS, EPS | `ps2pdf` → PDF |

---

## License
This driver is released under the MIT License.
Canon trademarks belong to Canon Inc.
