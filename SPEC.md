# CapturePilot Specification

## Overview

**Product Name**: CapturePilot  
**Tagline**: Hands-Free Screenshots: Fly Through Your Workflow.  
**Version**: 1.0.0 (Initial Release Target: Q2 2026)  
**Platform**: macOS (Apple Silicon optimized; Requires macOS 12.0 or later)  
**License Model**: One-time purchase with lifetime updates. No subscriptions.  
**Target Users**: Solo makers, power users, small teams (e.g., developers, designers, content creators, researchers archiving digital content).  
**Core Value Proposition**: Automate repetitive screenshot workflows to save time, enabling focus on creative or productive tasks. Supports archiving, batch processing, and video export for documentation.

This specification outlines the functional and non-functional requirements for CapturePilot, a native macOS app for automated screenshot capture and processing. It serves as the primary reference for the development team, including feature breakdowns, user flows, technical considerations, and testing guidelines.

**Key Differentiators**:
- Hands-free automation with interval timing and keystroke simulation.
- Versatile capture modes for apps, websites, and content archiving.
- Built-in timelapse video generation from capture sessions.
- Local-only processing (no cloud uploads) for privacy.
- Simple, intuitive UI with minimal setup.

**Development Phases**:
1. **MVP (v1.0)**: Core capture, automation, and export features.
2. **v1.1**: Enhanced web batching and timelapse refinements.
3. **v1.2**: Cross-app integrations and performance optimizations.

**Dependencies**:
- SwiftUI for UI (macOS 12+).
- AVFoundation for video export.
- WebKit for headless browser captures.
- No external APIs; all local.

## Functional Requirements

### 1. Core Capture Engine
The app must provide a robust, interruptible capture engine that runs in the background without blocking the user.

- **Hands-Free Interval Capture**:
  - Allow users to set a capture interval (e.g., 1 second to 60 minutes) via a slider or numeric input.
  - Support indefinite sessions or fixed duration (e.g., 10 minutes, 100 shots).
  - Automatically pause/resume on app focus loss or user intervention.
  - UI: Start/Stop button with live preview of next capture time.

- **Timed Screenshot Capture**:
  - One-time setup: User selects interval once; app handles all subsequent captures.
  - No manual triggers required after start.
  - Handle edge cases: System sleep, app crashes (auto-resume on relaunch).

- **Keypress Automation (Macros)**:
  - Simulate user-defined keystrokes (e.g., Cmd+Right Arrow for "next page") between captures.
  - Support delays (0-10 seconds) post-keystroke to allow UI updates.
  - Limit: Up to 5 sequential macros per session.
  - UI: Dropdown for common keys; custom input for modifiers/combos.
  - Differentiation from normal capture: Macros enable dynamic content (e.g., scrolling); normal is static timed shots.

- **Capture Area Selection**:
  - **Entire Screen**: Full display capture (multi-monitor support: primary only by default; option for all).
  - **Specific Window**: Drag-select or menu-pick active window; track window if it moves.
  - **Custom Area**: Drag-to-select rectangle; persist coordinates across sessions.
  - UI: Modal picker on session start; preview overlay.

- **Export Options**:
  - Formats: JPG (compressed), PNG (lossless), PDF (multi-page), ZIP (archived sequence).
  - Unlimited screenshots per session (no artificial limits).
  - Auto-save to user-designated folder; optional timestamp naming (e.g., "Capture_2026-02-07_14-30.png").
  - Batch export: Select all or range from session history.

### 2. Content Archiving Workflows
Specialized modes for common use cases, built on core engine.

- **Books & e-Readers**:
  - Automate page-by-page capture for digital books (e.g., PDF viewers, Kindle app).
  - Integration: Detect "next page" via macro; capture full page area.
  - Output: Sequential images/PDF ready for OCR or AI ingestion (e.g., "Stuff into ChatGPT").
  - UI: Pre-configured macro templates for popular apps (e.g., Preview.app, Books.app).

- **Webcomics & Manga**:
  - Record "next page" button click via macro simulation.
  - Handle infinite scroll or paginated sites (e.g., Webtoon, MangaDex).
  - Auto-detect and adapt to button positions if possible (via basic image recognition fallback).
  - UI: URL input + macro recorder (user demonstrates click once).

- **Any Other App**:
  - Universal compatibility: Works with any macOS app via accessibility APIs.
  - Simple configuration: 1-click setup for interval + optional macro.
  - Examples: Browsers (Safari/Chrome), productivity tools (Notion, Figma), terminals.

### 3. Website Batch Processing
Headless browser integration for automated web captures.

- **Bulk URL Processing**:
  - Input: List of URLs (up to 50; process in batches of 10 concurrent).
  - Concurrency: Up to 10 parallel headless sessions (throttle to avoid resource overload).
  - Progress tracking: Real-time dashboard showing completed/pending.

- **Responsive Viewport Options**:
  - Per-URL selection: Desktop (1920x1080), Tablet (1024x768), Mobile (375x667).
  - Custom viewport: Width/height inputs (min 320x480).
  - UI: Dropdown per URL in batch list.

- **Headless Background Capture**:
  - Use WebKit/WebDriver for invisible rendering.
  - No visible windows; full background execution.
  - Handle JS-heavy sites: Wait for DOM load (configurable timeout: 5-30s).
  - Error handling: Retry failed loads (up to 3x); log reasons (e.g., 404, timeout).

### 4. Timelapse Video Creation
Transform static captures into dynamic videos.

- **Session Recording**:
  - Auto-generate from any screenshot sequence (e.g., hours of work → 1-minute video).
  - Frame rate: User-selectable (1-60 FPS; default 30).
  - Speed controls: 2x-10x acceleration.

- **MP4 Export**:
  - Output: High-quality MP4 with H.264 codec.
  - Options: Add watermarks, transitions (fade/crossfade), audio (none/silent/system audio passthrough).
  - Resolution: Match source or upscale (via AVFoundation).

- **Workflow Documentation**:
  - Templates: Client update (professional), Tutorial (annotated), Personal journal (casual).
  - UI: One-click "Timelapse This Session" button post-capture.

### 5. User Management & Licensing
- **Device Limits**:
  - Personal: 1 macOS device.
  - Standard: 3 macOS devices.
  - Team: 5 macOS devices (shared license key).
- **Activation**: Enter license key on first launch; validate locally (no phoning home).
- **Transfer**: Allow key deactivation/reactivation via in-app tool.
- **Trial**: 14-day free trial with full features (watermark on exports).

## Non-Functional Requirements

- **Performance**:
  - Capture latency: <100ms per shot.
  - Memory: <200MB idle; scale linearly with session size.
  - CPU: <10% average during idle/background.

- **Security & Privacy**:
  - All data local: No uploads, telemetry, or cloud sync.
  - Permissions: Explicit requests for Screen Recording and Accessibility.
  - Copyright Notice: In-app disclaimer: "User responsible for captured content legality."
  - Audit: No logging of sensitive data (e.g., URLs, keystrokes).

- **Accessibility**:
  - VoiceOver support for all UI elements.
  - Keyboard navigation for all controls.
  - High-contrast mode.

- **Reliability**:
  - Crash recovery: Auto-save sessions every 10 shots.
  - macOS Integration: Respect Do Not Disturb, Low Power Mode.

- **Internationalization**:
  - English primary; prepare for localization (strings in Localizable.strings).

## User Flows & UI Guidelines

### Primary Flows
1. **New Session**:
   - Launch → Dashboard → Select Mode (App Capture/Web Batch/Timelapse Setup) → Configure (Interval/Area/Macro) → Start → Monitor/Stop → Export.

2. **Batch Web Capture**:
   - Dashboard → "Batch Websites" → Add URLs → Set Viewports → Start → View Gallery → Export.

3. **Timelapse Creation**:
   - Post-session → "Create Video" → Select Frames → Customize Speed/Effects → Export MP4.

### UI/Design Principles
- **Minimalist**: Clean SwiftUI interface; dark/light mode auto.
- **Components**:
  - Dashboard: Session history grid (thumbnails + metadata).
  - Config Panels: Collapsible accordions for advanced options.
  - Notifications: macOS-style banners for start/stop/errors.
- **Icons**: Use SF Symbols (e.g., camera.circle for capture).
- **Onboarding**: 3-step wizard on first launch (Permissions → Quick Setup → Sample Capture).

## Technical Architecture

- **App Structure**:
  - Main: SwiftUI AppDelegate.
  - Engine: Background NSOperationQueue for captures.
  - Browser: WKWebView (headless mode via process isolation).
  - Storage: Core Data for session metadata; FileManager for assets.

- **Data Models**:
  - `CaptureSession`: id, startTime, interval, areaType, macros[], exports[].
  - `Screenshot`: sessionId, timestamp, imagePath, metadata (viewport, URL).
  - `VideoExport`: sessionId, fps, duration, outputPath.

- **APIs/Integrations**:
  - Accessibility: AX API for window selection/keystrokes.
  - Screen Capture: CGDisplayStream for efficient grabs.
  - Export: NSImage → PDFKit; AVAssetExportSession for MP4.

- **Build Targets**:
  - Release: Apple Silicon universal binary.
  - Testing: Unit (XCTest for engine), UI (XCUITest for flows).

## Build and Installation Instructions

### Install Script
Provide a shell script named `install.command` in the project root to automate building the app and installing it to `~/Applications`. The script should:

1. Check for Xcode Command Line Tools (install if missing via `xcode-select --install`).
2. Build the app using `xcodebuild` (e.g., `xcodebuild -scheme CapturePilot -configuration Release -destination 'platform=macOS' archive` followed by export).
3. Create the `~/Applications` directory if it doesn't exist (`mkdir -p ~/Applications`).
4. Copy the built `.app` bundle to `~/Applications/CapturePilot.app`.
5. Make the app executable (`chmod +x ~/Applications/CapturePilot.app/Contents/MacOS/CapturePilot`).
6. Output success message with launch instructions.

Example script content (to be included in repo as `install.command`):

```bash
#!/bin/bash

echo "Building CapturePilot..."

# Install Xcode tools if needed
if ! command -v xcodebuild &> /dev/null; then
    xcode-select --install
fi

# Build and archive (adjust scheme/path as needed)
xcodebuild -scheme CapturePilot -configuration Release -destination 'platform=macOS' clean archive -archivePath ./build/CapturePilot.xcarchive

# Export app
xcodebuild -exportArchive -archivePath ./build/CapturePilot.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist

# Create Applications dir
mkdir -p ~/Applications

# Copy app
cp -R ./build/CapturePilot.app ~/Applications/

# Make executable
chmod +x ~/Applications/CapturePilot.app/Contents/MacOS/CapturePilot

echo "Installation complete! Launch CapturePilot from ~/Applications/CapturePilot.app"
echo "To open: open ~/Applications/CapturePilot.app"
```

Ensure the script is executable (`chmod +x install.command`) and includes error handling (e.g., `set -e` for exit on error).

### User Permissions Prompting
The app must handle macOS privacy permissions gracefully during onboarding and runtime. Implement the following:

1. **On First Launch (Onboarding Wizard)**:
   - Check for required permissions using `CGPreflightScreenCaptureAccess()` for Screen Recording and `AXIsProcessTrustedWithOptions()` for Accessibility.
   - If not granted, display a non-dismissible modal with:
     - Clear explanation: "CapturePilot needs Screen Recording to capture your screen and Accessibility to simulate keystrokes."
     - Direct links/buttons to System Settings: Use `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)` for Screen Recording and similar for Accessibility (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
     - Retry button to re-check after user visits Settings.
   - Block core features until permissions are granted (e.g., grayed-out Start button with tooltip).

2. **Runtime Checks**:
   - Before starting a session, verify permissions and prompt if revoked (e.g., via macOS notification or in-app banner).
   - Log permission status to console (not user-visible) for debugging.
   - Graceful fallback: If permissions denied, show error dialog with retry and Settings redirect.

3. **Edge Cases**:
   - Handle "Allow Once" vs. "Always Allow" for Screen Recording.
   - Support macOS versions <13 where APIs differ (use deprecation warnings).
   - Test on clean VM: Ensure prompts appear exactly once per permission type.

Integrate into the 3-step onboarding: Step 1 = Permissions.
