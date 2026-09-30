# Canon LBP2330 — Linux Driver & Installer

A clean PCL5e driver setup for the **Canon LBP2330** on Linux, fixing two known issues:
- `universal filter failed` — caused by missing `foomatic-rip` binary
- Progressive bottom-right page drift — caused by `-dPDFFitPage` in the Ghostscript command

Tested on Arch Linux. Installer supports Arch/Manjaro, Debian/Ubuntu, and Fedora/RHEL.

---

## Files

| File | Description |
|------|-------------|
| `install.sh` | Full installer — installs deps, writes PPD, registers printer |
| `canon-lbp2330-fixed.ppd` | The fixed PPD file (also embedded inside `install.sh`) |

---

## Quick Start

Plug in the printer, power it on, then:

```bash
sudo bash install.sh
```

That's it. The script handles everything.

---

## What the Installer Does

1. **Detects your distro** (pacman / apt / dnf) and installs the right packages
2. **Verifies** that `gs`, `foomatic-rip`, `cupsd`, and `lpadmin` are all present
3. **Writes the PPD** to `/usr/share/cups/model/canon-lbp2330.ppd`
4. **Starts CUPS** via systemctl
5. **Auto-detects the printer URI** via `lpinfo -v` — prompts for manual entry if not found
6. **Registers the print queue** as `Canon-LBP2330`, sets A4 default, marks as system default
7. **Enables** the queue and accepts jobs

---

## Dependencies Installed

### Arch / Manjaro
```
cups  cups-filters  ghostscript
foomatic-db  foomatic-db-engine  foomatic-db-nonfree
foomatic-db-nonfree-ppds  gsfonts  a2ps
```
> `foomatic-rip` is provided by `foomatic-db-engine` on Arch — there is no standalone `foomatic-rip` package.

### Debian / Ubuntu
```
cups  cups-filters  ghostscript
foomatic-db  foomatic-db-engine  foomatic-filters
printer-driver-gutenprint  gsfonts  a2ps  libcups2
```

### Fedora / RHEL
```
cups  cups-filters  ghostscript
foomatic  foomatic-db  foomatic-db-ppds  foomatic-filters
gsfonts  a2ps
```

---

## PPD Changes (vs. original)

| Setting | Original | Fixed |
|---------|----------|-------|
| `cupsFilter` | `foomatic-rip` (not installed) | `foomatic-rip` (now installed by script) |
| GS device | `ljet4d` | `ljet4` (more stable, avoids duplex signal issues) |
| `-dPDFFitPage` | Present (caused page drift) | **Removed** |
| `-dFIXEDMEDIA` | Present | Kept |

---

## Manual Printer Management

```bash
# Check printer status
lpstat -p Canon-LBP2330 -l

# Test print
echo "Test Page" | lp -d Canon-LBP2330

# Print a PDF
lp -d Canon-LBP2330 /path/to/file.pdf

# Remove the printer queue
sudo lpadmin -x Canon-LBP2330

# Re-run installer (safe to run again — removes old queue first)
sudo bash install.sh
```

---

## Troubleshooting

**"universal filter failed"**
```bash
which foomatic-rip   # must return a path
which gs             # must return a path
sudo systemctl restart cups
```

**Printer not detected during install**
The script will prompt for a URI. Find it with:
```bash
lpinfo -v
# look for a line like: direct usb://Canon/LBP2330?serial=...
```

**CUPS web interface**
Browse to `http://localhost:631` to manage printers visually.

**Check CUPS logs for errors**
```bash
journalctl -u cups -f
# or
sudo tail -f /var/log/cups/error_log
```

---

## Printer Specs

| | |
|---|---|
| Model | Canon LBP2330 |
| Language | PCL5e |
| GS Device | `ljet4` |
| Paper | A4 (595×842 pt) |
| Imageable Area | 12 12 583 830 |
| Tray | Tray 1 (`dMediaPosition=1`) |
| Duplex | Supported (long & short edge) |
