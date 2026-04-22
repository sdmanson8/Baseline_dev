"""
Rewrites WhyThisMatters fields in the 6 flagged JSON data files.
Rules: no restating Detail, no stock phrases, plain specific prose, concrete tradeoffs.
"""
import json
import os

BASE = os.path.join(os.path.dirname(__file__), '..', 'Module', 'Data')

REWRITES = {
    # === Defender.json ===
    "Account Protection Warning": (
        "Hides the recurring Windows Security nag to sign into a Microsoft account. "
        "Security posture is unchanged; this only removes the notification."
    ),
    "Apps SmartScreen": (
        "When you run an unfamiliar executable, SmartScreen checks its reputation against "
        "Microsoft's cloud database and blocks or warns if it is unknown or flagged. "
        "Disabling means no reputation check runs before execution."
    ),
    "Boot Recovery": (
        "Without automatic recovery, a machine that fails to boot consecutively will stay at "
        "the boot menu rather than entering WinRE automatically. Useful on headless systems "
        "where WinRE loops are harder to interrupt."
    ),
    "Core Isolation Memory Integrity": (
        "Runs kernel code integrity checks inside a hypervisor-protected environment so "
        "kernel-level malware cannot tamper with driver signing verification. "
        "Incompatible drivers will be blocked from loading after enabling."
    ),
    "Defender Application Guard": (
        "Runs untrusted Edge tabs inside an isolated VM so a compromised tab cannot "
        "read host files or credentials. Requires hardware virtualization and adds "
        "per-tab startup latency."
    ),
    "Defender Cloud": (
        "Submits unknown files to Microsoft's threat intelligence backend for real-time "
        "analysis. Without it, Defender relies only on local signatures and heuristics, "
        "which can miss novel malware until the next definition update."
    ),
    "Defender Exploit Guard Policy": (
        "Applies a set of Attack Surface Reduction rules that block common malware "
        "execution patterns — macro abuse, Office child processes, script injection, "
        "and others. Individual rules can be audited or excluded if they conflict with "
        "legitimate software."
    ),
    "Defender Sandbox": (
        "Runs the Defender scanning engine in an isolated process so a vulnerability in "
        "the scanner itself cannot be exploited to reach the rest of the OS. "
        "Adds a modest CPU overhead."
    ),
    "Defender Tray Icon": (
        "Cosmetic only — removing the tray icon does not disable or weaken Defender protection."
    ),
    "DEP OptOut": (
        "Enables Data Execution Prevention for every process on the system except those "
        "you explicitly exempt. OptOut means DEP is on by default and you opt individual "
        "programs out rather than having to opt them in."
    ),
    "Dismiss MS Account Offer": (
        "Suppresses the persistent Windows Security prompt to link a Microsoft account. "
        "Does not affect authentication or security policy."
    ),
    "Dismiss SmartScreen Filter Offer": (
        "Suppresses the persistent Windows Security prompt to turn on SmartScreen. "
        "Does not change whether SmartScreen is actually enabled."
    ),
    "DNS over HTTPS": (
        "Routes DNS queries over an encrypted HTTPS connection instead of plaintext UDP port 53. "
        "Prevents ISPs and network observers from reading your lookup traffic. "
        "Requires a DoH-capable resolver — choose a preset or enter a custom server URL."
    ),
    "Download File Blocking": (
        "Controls whether Windows stamps downloaded files with a Zone.Identifier ADS "
        "marking them as coming from the internet. Removing this mark bypasses 'Open file "
        "– security warning' prompts but also silences warnings on genuinely risky files."
    ),
    "Event Viewer Custom View": (
        "Registers a pre-built Event Viewer filter scoped to process creation events. "
        "Useful when investigating what ran on a machine without writing a custom query."
    ),
    "F8 Boot Menu": (
        "Restores the pre-Windows 8 behavior where tapping F8 during POST opens the "
        "advanced boot menu. Modern UEFI fast boot makes this menu unreachable without "
        "explicitly re-enabling it."
    ),
    "Firewall": (
        "Windows Defender Firewall applies to all network profiles. Disabling it leaves "
        "every listening port exposed with no inbound filtering. Only disable if a "
        "third-party firewall is running in its place."
    ),
    "Import Exploit Protection Policy": (
        "Downloads and imports a community-maintained exploit mitigation policy file that "
        "configures per-process mitigations beyond the system defaults. "
        "Policies may need adjustment for software that conflicts with specific mitigations."
    ),
    "Local Security Authority Protection": (
        "Runs the LSA process in isolated protected mode so credential-dumping tools "
        "like Mimikatz cannot read LSASS memory directly. "
        "Recommended on any system where credential theft is a realistic concern."
    ),
    "LOLBin Firewall Rules": (
        "Adds outbound block rules for built-in Windows binaries routinely abused to "
        "download payloads or phone home — certutil, bitsadmin, mshta, and similar. "
        "Verify that none of these binaries are required by your legitimate automation "
        "before applying."
    ),
    "Network Protection": (
        "Blocks connections to known malicious domains and IPs at the network driver "
        "level using Defender's threat intelligence. Operates system-wide, not just "
        "within a browser."
    ),
    "PowerShell Module Logging": (
        "Writes every command executed by PowerShell modules to the Windows event log "
        "(Event ID 4103). Expands visibility for incident response but can produce high "
        "log volume on systems that run automation."
    ),
    "PowerShell Script Logging": (
        "Captures the full decoded content of every script block PowerShell executes "
        "(Event ID 4104), including dynamically constructed code. "
        "Essential for post-incident forensics; volume scales with script activity."
    ),
    "PUA Detection": (
        "Tells Defender to flag and quarantine potentially unwanted applications — adware, "
        "bundleware, browser hijackers, and coin miners. "
        "Can produce false positives on gray-area utilities like system cleaners."
    ),
    "Save Zone Information": (
        "Keeps the Zone.Identifier ADS on downloaded files so Windows can show security "
        "prompts before running them. Removing this mark means no zone-based warning "
        "will appear even for files downloaded from the internet."
    ),
    "Sharing Mapped Drives": (
        "When disabled (the UAC default), elevated processes see drive letters differently "
        "from the user session, which can break scripts that assume mapped drives are "
        "visible under elevation. Enabling this makes them consistent."
    ),
    "Windows Firewall Logging": (
        "Writes allowed and dropped connection records to the Windows Firewall log file. "
        "Provides a network-level audit trail without requiring a full packet capture."
    ),
    "Windows Sandbox": (
        "Provisions a lightweight throwaway VM you can spin up on demand for testing "
        "untrusted software. Requires Windows Pro or higher and hardware virtualization. "
        "Everything inside is discarded when the sandbox window closes."
    ),
    "Windows Script Host": (
        "Controls execution of .vbs and .js script files via wscript.exe and cscript.exe. "
        "Disabling blocks these script types from running when double-clicked or "
        "invoked without a full interpreter path — a common malware delivery path."
    ),

    # === OSHardening.json ===
    "Remote Commands (DCOM)": (
        "DCOM remote activation is used by enterprise management tools like SCCM and WMI. "
        "Disabling it reduces the remote attack surface but will break workflows that rely "
        "on remote COM activation."
    ),
    "Configure Cipher Suites": (
        "Restricts SCHANNEL to AES-256 and AES-128 cipher suites for all TLS connections. "
        "Older clients or servers that do not support these suites will fail to negotiate."
    ),
    "Configure Event Log Sizes": (
        "Raises the Windows Security event log cap so audit events are retained longer "
        "before they roll over. On active systems with verbose auditing the 1 MB default "
        "can fill within hours."
    ),
    "Configure Key Exchange Algorithms": (
        "Enables Diffie-Hellman, ECDH, and PKCS key exchange in SCHANNEL so forward-secure "
        "key exchange is available for TLS. Without these, some TLS handshakes fall back "
        "to non-forward-secret key exchange."
    ),
    "Legacy TLS Protocols (1.0/1.1)": (
        "TLS 1.0 and 1.1 are deprecated per RFC 8996 and are vulnerable to BEAST, POODLE, "
        "and related downgrade attacks. Re-enable only if you must interoperate with a "
        "device that cannot be upgraded to TLS 1.2."
    ),
    "Configure Strong .NET Authentication": (
        "Forces .NET 4.x and 2.x to negotiate using the OS TLS policy rather than their own "
        "hardcoded cipher list. Prevents older .NET apps from silently falling back to "
        "weak ciphers when the server offers them."
    ),
    "Disable AES Ciphers": (
        "Removes older weak AES cipher entries from the SCHANNEL allowed list so they "
        "cannot be negotiated even if a remote peer requests them."
    ),
    "Disable AutoRun": (
        "Prevents Windows from executing autorun.inf programs on removable media. "
        "This was a primary USB worm propagation mechanism and remains a baseline "
        "hardening step even on modern systems."
    ),
    "Disable IPv6": (
        "Removes the IPv6 stack system-wide. If your network infrastructure does not use "
        "IPv6, the protocol expands attack surface without providing value. "
        "IPv6-dependent services will break if this is applied to a network that uses it."
    ),
    "Disable RC2 and RC4 Ciphers": (
        "RC2 and RC4 are cryptographically broken. Any TLS session negotiated with these "
        "ciphers can be decrypted offline. No legitimate modern server should require them."
    ),
    "Disable SMBv3 Compression": (
        "Addresses CVE-2020-0796, a pre-auth remote code execution vulnerability in the "
        "SMBv3 compression path. Turning off compression removes the vulnerable code path "
        "without affecting normal file transfer throughput."
    ),
    "Disable TCP Timestamps": (
        "TCP timestamps let remote hosts estimate your system uptime and can narrow OS "
        "fingerprinting. Removing them is a passive reconnaissance hardening step."
    ),
    "Disable Triple DES Cipher": (
        "3DES is vulnerable to the SWEET32 birthday attack at practical data volumes. "
        "It should not be negotiated in any TLS session."
    ),
    "Disable Weak Hash Algorithms": (
        "Disables MD5 in SCHANNEL and ensures the SHA family is enabled. "
        "MD5 is collision-broken and should not appear in certificate or MAC operations."
    ),
    "Enable Biometrics Anti-Spoofing": (
        "Enables enhanced liveness detection for Windows Hello facial recognition on "
        "compatible cameras. Without it, a printed photo or screen can potentially unlock "
        "the device."
    ),
    "Ensure Registry Paths Exist": (
        "Creates registry key paths that other hardening tweaks expect to exist before they "
        "write values. This runs as a prerequisite step and has no direct user-facing effect."
    ),
    "Filesystem Performance Settings": (
        "Disables 8.3 short filename generation (e.g. PROGRA~1) on NTFS volumes. "
        "8.3 names are a DOS compatibility feature that adds write overhead on every "
        "file creation and is rarely needed today."
    ),
    "General OS Hardening": (
        "Writes a broad set of registry values covering credential guard, UAC, NTLM relay "
        "protections, TCP/IP stack hardening, and smart card removal behavior. "
        "Review the individual values before applying on domain-joined or managed systems."
    ),
    "Harden Adobe Reader": (
        "Applies Adobe Reader DC policy settings enabling Protected Mode, Protected View, "
        "and Enhanced Security while disabling cloud services, JavaScript execution, and "
        "external content loading. May break workflows that depend on Reader's cloud or "
        "form features."
    ),
    "Harden ClickOnce Trust Prompts": (
        "Blocks ClickOnce applications from prompting for elevated trust in any security "
        "zone. Prevents untrusted .NET applications distributed via ClickOnce from "
        "installing without explicit policy approval."
    ),
    "Harden MS Office": (
        "Restricts VBA macros to digitally signed sources, blocks external content and DDE "
        "links, and tightens Outlook trust settings across Office versions. "
        "Document-based attacks frequently rely on these vectors."
    ),
    "Harden Office Links": (
        "Stops Word from automatically refreshing external links on document open. "
        "Auto-refreshing external links is a data exfiltration technique used in phishing "
        "documents to beacon back to an attacker-controlled server."
    ),
    "Harden WinRM": (
        "Disables unencrypted WinRM transport and digest authentication, then restarts the "
        "WinRM service. After this change, remote PowerShell sessions require HTTPS or "
        "Kerberos."
    ),
    "Prevent Remote DLL Hijacking": (
        "Sets the DLL search order so Windows looks in system directories before the "
        "current directory. Applications that bundle DLLs in their working directory and "
        "rely on implicit load order may need explicit path updates."
    ),
    "Prevent Wireless Exploitation": (
        "Removes the network selector from the Windows lock screen so an attacker with "
        "physical access cannot change the network connection before authenticating."
    ),
    "Reduce RPC Surface": (
        "Disables RPC-over-TCP for the remote Task Scheduler and remote Service Control "
        "Manager. These interfaces are used in lateral movement and remote execution "
        "techniques."
    ),

    # === PrivacyTelemetry.json ===
    "Activity History": (
        "When enabled with a Microsoft account, Windows records which apps and files you "
        "open and can sync this timeline to the cloud. Disabling keeps usage history "
        "off Microsoft's servers."
    ),
    "Advertising ID": (
        "Each Windows account gets a persistent advertising identifier apps can read to "
        "build an ad targeting profile. Disabling resets and stops issuing the ID."
    ),
    "Auto Reboot on Crash (BSOD)": (
        "Leaving auto-reboot enabled means a blue screen disappears before you can note "
        "the stop code. Disabling keeps the crash display on screen until you manually "
        "restart."
    ),
    "Auto Restart After Update": (
        "Stops Windows from rebooting on its own schedule after installing an update. "
        "The machine will prompt instead of restarting mid-session."
    ),
    "Automatic Map Updates": (
        "Background downloads of offline map data for the Windows Maps app. "
        "If you do not use Maps, this is unnecessary background network activity."
    ),
    "Online Speech Recognition": (
        "Sends voice input to Microsoft's cloud recognition service. "
        "Disabling forces speech processing to stay on-device, which reduces accuracy "
        "for some recognition tasks."
    ),
    "Narrator Online Services": (
        "Allows Narrator to call Microsoft cloud APIs for enhanced image descriptions and "
        "natural-sounding voices. Disabling limits Narrator to local TTS voices."
    ),
    "Narrator Scripting Support": (
        "Allows Narrator to run automation scripts for custom behavior. "
        "Low-risk to disable unless you have Narrator scripts in place."
    ),
    "Inking and Typing Personalization": (
        "Builds a local model of your typing patterns and handwriting to improve "
        "suggestions. The data stays on-device but disabling prevents any personalization "
        "model from being built."
    ),
    "Device Search History": (
        "Windows Search logs your local queries so it can prioritize recent results. "
        "Disabling stops the log from accumulating."
    ),
    "Cloud Content Search": (
        "Extends Start menu and Windows Search results to include content from your "
        "Microsoft account or work account. Disabling limits results to local content only."
    ),
    "Block Workplace Join Messages": (
        "Suppresses the sign-in prompts that offer to enroll the device in organizational "
        "management. Useful on personal machines where MDM enrollment is not intended."
    ),
    "Prevent BitLocker Auto Encryption": (
        "Stops Windows from silently enabling BitLocker drive encryption during initial "
        "setup on eligible hardware. Encryption only activates when you explicitly choose it."
    ),
    "Camera Access": (
        "System-wide toggle for camera access. When disabled, no app can use the camera "
        "regardless of its individual permission setting."
    ),
    "Clipboard History": (
        "Enables a persistent clipboard stack accessible via Win+V so you can paste from "
        "earlier copied items. Clipboard contents are stored in memory; sync to other "
        "devices requires an additional setting."
    ),
    "Connected User Experiences (DiagTrack)": (
        "The DiagTrack service is the primary Windows telemetry uploader. Stopping and "
        "disabling it ends background data collection and upload to Microsoft. "
        "Windows Update and error reporting still function without it."
    ),
    "Device Sensors": (
        "Controls app access to hardware sensors such as accelerometer, gyroscope, and "
        "ambient light. Primarily relevant on tablets and convertibles — negligible on "
        "desktop systems without these sensors."
    ),
    "Diagnostic Data Level": (
        "Sets how much telemetry Windows sends to Microsoft. Minimal sends only required "
        "device health and crash data. Security (enterprise only) sends no optional data."
    ),
    "Diagnostics Tracking Tasks": (
        "Disables the scheduled tasks that collect and upload diagnostic data on a timer. "
        "These run independently of the DiagTrack service setting."
    ),
    "Display and Sleep Timeouts": (
        "Sets how long the system waits before turning off the display or entering sleep "
        "on AC and DC power. Use zero to prevent sleep entirely."
    ),
    "Driver Updates via Windows Update": (
        "Controls whether Windows Update fetches hardware driver updates automatically. "
        "Disabling lets you source drivers directly from the manufacturer and avoid "
        "Windows-supplied versions."
    ),
    "Fast Startup": (
        "Saves the kernel state to the hibernation file on shutdown so the next boot "
        "resumes rather than cold-starts. Can prevent full memory flush, interfere with "
        "dual-boot setups, or cause stale driver state after updates."
    ),
    "Feedback Frequency": (
        "Controls how often Windows prompts you to submit feedback or rate your experience. "
        "Setting to Never eliminates these prompts entirely."
    ),
    "Language List Access for Websites": (
        "Allows websites to read your Windows language preference list via the Accept-Language "
        "header. Disabling sends a generic language preference rather than your specific list."
    ),
    "Location Services": (
        "System-wide toggle for location access. When disabled, no app can request the "
        "device's geographic position regardless of individual app permissions."
    ),
    "Lock Screen Widgets": (
        "The Windows Web Experience Pack serves the lock screen news feed and taskbar "
        "weather widget. Removing it clears these from the lock screen and taskbar."
    ),
    "Maintenance Wake-up": (
        "Allows Windows to wake the machine from sleep overnight to run scheduled "
        "maintenance. Disabling prevents unwanted overnight power-on events."
    ),
    "Malicious Software Removal Tool (MSRT)": (
        "Controls whether Windows Update pushes the MSRT for periodic scanning. "
        "Disabling prevents the tool from being automatically downloaded and run."
    ),
    "Microphone Access": (
        "System-wide toggle for microphone access. When disabled, no app can capture audio "
        "input regardless of individual app permissions."
    ),
    "Microsoft Product Updates": (
        "Extends Windows Update to also service other Microsoft products like Office. "
        "Disabling limits the Windows Update agent to OS patches only."
    ),
    "NTFS Last Access Timestamps": (
        "NTFS updates a last-access timestamp on every file read. On read-heavy workloads "
        "this generates significant write amplification. Disabling removes this overhead."
    ),
    "NTFS Long Paths": (
        "Removes the 260-character MAX_PATH limit for NTFS. Required for deep Git repos, "
        "Python virtual environments, and other tools that generate long paths."
    ),
    "Shared Experiences": (
        "Allows Windows to relay activity between devices via your Microsoft account, "
        "enabling cross-device handoff and nearby sharing. Disabling keeps activity scoped "
        "to this machine."
    ),
    "Sign-in Info After Update": (
        "Uses cached credentials to auto-complete your profile setup after a Windows update "
        "reboot. Disabling requires manual sign-in to finish each post-update setup."
    ),
    "Sleep Button": (
        "Controls whether the Start Menu Sleep option and the keyboard sleep key are active. "
        "Disable if you want to prevent accidental sleep from keyboard shortcuts."
    ),
    "Superfetch Service": (
        "SysMain preloads likely-used apps into RAM ahead of demand. On SSDs the latency "
        "benefit is minimal and the background I/O can be disruptive. On HDDs it may "
        "noticeably improve launch times."
    ),
    "Tailored Experiences": (
        "Uses diagnostic data to show Microsoft-curated tips, ads, and suggestions inside "
        "Windows. Disabling opts out of this personalization."
    ),
    "UWP Account Info": (
        "Controls whether UWP apps can read your account name and profile picture. "
        "Disable if you do not want apps to identify your account details."
    ),
    "UWP Calendar": (
        "Controls whether UWP apps can read or write calendar entries. "
        "Disable if calendar app integration is not needed."
    ),
    "UWP Call History": (
        "Controls whether UWP apps can read your call log. Relevant on Windows Mobile; "
        "on desktop this is typically unused."
    ),
    "UWP Contacts": (
        "Controls whether UWP apps can access your contacts list."
    ),
    "UWP Diagnostic Info": (
        "Controls whether UWP apps can query device diagnostic information such as battery "
        "level, hardware specs, and app list."
    ),
    "UWP Email": (
        "Controls whether UWP apps can read and compose email on your behalf."
    ),
    "UWP File System": (
        "Controls whether UWP apps can access arbitrary file system locations outside their "
        "own app container. Disabling restricts UWP apps to their sandboxed storage only."
    ),
    "UWP Messaging": (
        "Controls whether UWP apps can send and read SMS and MMS messages."
    ),
    "UWP Notifications": (
        "Controls whether UWP apps can push notifications to the Action Center."
    ),
    "UWP Other Devices": (
        "Controls whether UWP apps can communicate with paired devices not covered by "
        "more specific permission categories."
    ),
    "UWP Phone Calls": (
        "Controls whether UWP apps can initiate and manage phone calls."
    ),
    "UWP Radios (Bluetooth)": (
        "Controls whether UWP apps can enable or disable Bluetooth and other radio devices."
    ),
    "UWP Swap File": (
        "The swapfile.sys file provides virtual memory backing for UWP apps. "
        "Disabling frees disk space and may reduce paging activity if you have removed "
        "all Store apps."
    ),
    "UWP Tasks": (
        "Controls whether UWP apps can access your task and to-do list data."
    ),
    "UWP Voice Activation": (
        "Controls whether UWP apps can respond to voice triggers while running in the "
        "background. Disabling prevents always-on wake-word listeners."
    ),
    "WAP Push Messaging": (
        "The WAP Push service processes over-the-air provisioning messages from mobile "
        "carriers. Essentially unused on PCs not connected to a mobile network."
    ),
    "Web Language Sync": (
        "Syncs your Windows language preference list to Microsoft servers. "
        "Disable to prevent this list from leaving the device."
    ),
    "WiFi Sense": (
        "WiFi Sense can share saved network credentials with your Outlook, Skype, and "
        "Facebook contacts so they connect automatically. Disabling prevents any credential "
        "sharing."
    ),
    "Windows Error Reporting": (
        "Sends crash dumps and error reports to Microsoft after application or OS failures. "
        "Disabling stops this data from leaving the machine."
    ),
    "Windows Update Auto Downloads": (
        "Controls whether Windows Update downloads updates automatically in the background. "
        "Disabling means updates are only downloaded when you manually check."
    ),

    # === System.json ===
    "Advanced Startup Desktop Shortcut": (
        "Creates a shortcut that triggers an immediate reboot into the Windows Recovery "
        "Environment advanced startup menu. Useful when the F8 boot key is unavailable."
    ),
    "Silent App Installing": (
        "Stops Windows from installing suggested apps in the background without prompting. "
        "Prevents sponsored apps from appearing after a clean install or reset."
    ),
    "Active Hours": (
        "Tells Windows not to initiate automatic restarts during your specified hours. "
        "Updates will still install; only the forced-restart window is restricted."
    ),
    "Admin Approval Mode (UAC)": (
        "Sets how UAC handles elevation requests. Higher levels prompt with a credential "
        "dialog; lower levels use a consent prompt or bypass the prompt entirely. "
        "Disabling means any process can silently gain administrator rights."
    ),
    "AutoPlay": (
        "Controls whether Windows shows a dialog or launches an app automatically when "
        "removable media is inserted. Disable to always require a manual action."
    ),
    "BSoD Stop Error Code": (
        "Adds the specific stop code to the blue screen display. Without it you only "
        "see a generic error page and must dig through event logs to find the code."
    ),
    "Caps Lock": (
        "Remaps Caps Lock to a no-op at the registry level. The key is still physically "
        "present but pressing it has no effect."
    ),
    "Client for Microsoft Networks": (
        "The SMB client component that allows this PC to connect to remote Windows file "
        "and printer shares. Disabling prevents all SMB outbound connections."
    ),
    "Current Network Profile": (
        "Private profile enables network discovery and file sharing. Public profile "
        "restricts both. This controls the active connection only, not future connections."
    ),
    "Default Input Method": (
        "Pins the keyboard input method so Windows uses the English layout by default "
        "even when other language packs are installed."
    ),
    "Default Terminal App": (
        "Selects which terminal host opens when Command Prompt or PowerShell is launched "
        "from within Windows, such as from the Run dialog or context menus."
    ),
    "Delivery Optimization": (
        "Allows this PC to serve Windows Update download data to other PCs on your LAN or "
        "the internet. Disabling keeps update bandwidth usage private to this machine."
    ),
    "DNS Provider Presets": (
        "Writes DNS server addresses to all network adapters that are currently up. "
        "Choose DHCP to revert to automatic assignment or Default to leave existing "
        "settings unchanged."
    ),
    "F1 Help Lookup": (
        "Pressing F1 in File Explorer launches the Windows help website in the default "
        "browser. Disabling prevents this key from triggering browser launches."
    ),
    "File and Printer Sharing (SMB Server)": (
        "Enables the inbound SMB server so other machines on the network can access shares "
        "and printers on this PC. Disable if this machine does not need to serve files."
    ),
    "Get Latest Updates ASAP": (
        "Enrolls the PC in the earliest-available update wave. Useful for staying current "
        "on security patches; carries higher risk of receiving patches before widespread "
        "testing has surfaced regressions."
    ),
    "Download Updates Over Metered Connection": (
        "Controls automatic update downloads when on a metered connection. "
        "Disabling prevents update traffic from counting against a data cap."
    ),
    "Feature Update Deferral": (
        "Delays major Windows version upgrades by up to 365 days. Useful for stability, "
        "but extended deferral can push the machine past a version's end-of-support date."
    ),
    "Quality Update Deferral Period": (
        "Delays monthly security and quality patches by 4 or 7 days. Gives time for early "
        "adopters to surface patch regressions before you apply."
    ),
    "Hibernation": (
        "Full hibernation writes all RAM to hiberfil.sys and cuts power completely, unlike "
        "Fast Startup which only saves kernel state. The hibernation file can be several "
        "gigabytes depending on installed RAM."
    ),
    "Home Groups": (
        "Home Groups was removed in Windows 10 1803, but residual services may still be "
        "registered. This cleans up those leftover components."
    ),
    "Internet Connection Sharing": (
        "Allows this PC to act as a NAT gateway, sharing its internet connection with "
        "other devices. Exposes a DHCP server and routing on the sharing adapter."
    ),
    "Latest .NET Runtime for All Apps": (
        "Forces 32-bit and 64-bit processes to bind to the newest installed .NET runtime "
        "rather than the version they were compiled against. Can expose compatibility "
        "issues in older applications."
    ),
    "LLMNR Protocol": (
        "LLMNR resolves hostnames on the local network without DNS. It responds to "
        "broadcast queries, making it exploitable for credential capture via Responder "
        "or similar tools. Disable on any network where you do not explicitly need it."
    ),
    "NCSI Probe": (
        "The Network Connectivity Status Indicator probes Microsoft servers to determine "
        "internet reachability and set the network icon. Disabling may cause the icon to "
        "show no internet even when connectivity exists."
    ),
    "NetBIOS over TCP/IP": (
        "NetBIOS name resolution is exploitable for credential capture on local networks "
        "(NBNS poisoning). Modern networks that use DNS exclusively do not need it."
    ),
    "Network Adapters Save Power": (
        "When enabled, Windows can cut adapter power after an idle period. "
        "Disabling this prevents brief connection drops that occur when the adapter wakes."
    ),
    "Network Devices Auto Install": (
        "Controls whether Windows automatically fetches and installs drivers for newly "
        "plugged-in network devices. Disabling requires manual driver installation."
    ),
    "Network Discovery": (
        "Allows this PC to see other devices on the LAN and be seen by them. "
        "Required for browsing network shares by name in File Explorer."
    ),
    "New App Prompt": (
        "When a file with no associated application is opened, Windows shows a dialog "
        "offering to search the Store or browse locally. Disabling suppresses this prompt."
    ),
    "NTP Server Override": (
        "Points the Windows Time service at pool.ntp.org instead of the Microsoft time "
        "server. Uses the NTP pool's anycast infrastructure for time synchronization."
    ),
    "Num Lock at Startup": (
        "Forces Num Lock on or off at each startup regardless of the BIOS setting or "
        "previous state."
    ),
    "OpenSSH Server": (
        "Installs the OpenSSH Server Windows capability, starts sshd, and opens port 22 "
        "in the firewall. After enabling, the machine accepts inbound SSH connections."
    ),
    "Power Plan": (
        "Balanced scales CPU frequency with demand. High Performance keeps the CPU at "
        "maximum clock at the cost of higher power draw. Ultimate Performance removes all "
        "remaining throttling and is not available on battery-powered systems by default."
    ),
    "Processor Minimum State": (
        "Sets the floor for CPU frequency scaling on AC and DC power. Raising it prevents "
        "the CPU from dropping to idle clocks but increases power draw at low load."
    ),
    "Processor Maximum State": (
        "Sets the ceiling for CPU frequency scaling. Lowering below 100% caps thermal and "
        "power output at the cost of peak performance."
    ),
    "Processor Performance Increase Threshold": (
        "The CPU utilization level that must be sustained before Windows increases clock "
        "speed. Lower values make the CPU ramp up more eagerly."
    ),
    "Processor Performance Decrease Threshold": (
        "The CPU utilization level that must fall below before Windows reduces clock speed. "
        "Higher values keep clocks elevated longer before stepping down."
    ),
    "Processor Performance Boost Mode": (
        "Selects how Windows uses processor boost headroom — aggressive, efficient, or "
        "autonomous. Affects how quickly and how often the CPU enters boost states."
    ),
    "CPU Core Parking Minimum Cores": (
        "Sets the minimum percentage of cores Windows must keep unparked. "
        "Lower values allow more aggressive core parking at idle."
    ),
    "CPU Core Parking Maximum Cores": (
        "Sets the maximum percentage of cores Windows is allowed to keep active. "
        "Set to 100% to prevent Windows from parking any cores."
    ),
    "Processor Energy Performance Preference": (
        "On modern CPUs with efficiency cores, this hint shifts scheduling toward "
        "performance cores (low value) or efficiency cores (high value)."
    ),
    "USB Hub Selective Suspend Timeout": (
        "Sets the idle timeout before USB hubs power down. Shorter values save more power "
        "at the cost of a brief delay when the hub wakes."
    ),
    "USB selective suspend setting": (
        "Allows Windows to cut power to idle USB ports. Disable if you have a device "
        "that loses state or connectivity when the port suspends."
    ),
    "Intel(R) Graphics Power Plan": (
        "Selects the Intel integrated GPU power profile between maximum battery savings "
        "and maximum performance. Only applies to Intel iGPU systems."
    ),
    "Video Playback Quality Bias": (
        "Tells Windows to prioritize smooth video decoding over battery conservation "
        "during video playback."
    ),
    "Power Throttling": (
        "Power throttling reduces background app CPU frequency to save energy. "
        "Disabling it prevents Windows from down-clocking background workloads."
    ),
    "Prevent Edge Shortcut Creation": (
        "Blocks Edge from re-adding its desktop shortcut after updates and channel upgrades. "
        "Applies to Stable, Beta, Dev, and Canary channels."
    ),
    "QoS Packet Scheduler": (
        "The QoS packet scheduler is required for applications that use network traffic "
        "prioritization APIs. It does not throttle bandwidth on its own."
    ),
    "Recommended Troubleshooting": (
        "Controls whether Windows automatically runs built-in troubleshooters when it "
        "detects a known problem. Default still asks for permission; disable to prevent "
        "automatic troubleshooter runs entirely."
    ),
    "Registry Backup": (
        "Configures Windows to write periodic backups of the registry hive files to the "
        "RegBack folder. Required since Windows 10 1803 disabled this by default."
    ),
    "Reserved Storage": (
        "Windows reserves a fixed disk allocation for updates, temp files, and OS caches. "
        "Disabling reclaims that space after the next feature update applies the change."
    ),
    "Restart After Update": (
        "Allows Windows to schedule an immediate restart once an update finishes installing "
        "rather than waiting for the next scheduled window."
    ),
    "Restart Required Notification": (
        "Shows a persistent taskbar indicator when a pending update is waiting for a "
        "restart to complete installation."
    ),
    "Update Notification Level": (
        "Controls which Windows Update notifications are shown. Hiding them prevents "
        "restart prompts from appearing, which can lead to missed updates if not "
        "monitored elsewhere."
    ),
    "Save Restartable Apps": (
        "Windows saves the state of open apps at sign-out and reopens them automatically "
        "at the next sign-in."
    ),
    "Search App in Store for Unknown Ext.": (
        "When opening a file with an unrecognized extension, Windows can suggest searching "
        "the Store for a compatible app. Disabling skips this Store lookup."
    ),
    "Block Microsoft Store Search Results": (
        "Suppresses Store app recommendations from appearing in Start menu app search "
        "results alongside locally installed apps."
    ),
    "SMB 1.0 Protocol": (
        "SMBv1 has no encryption and is the protocol exploited by EternalBlue. "
        "It should be disabled unless an old NAS, printer, or legacy device that cannot "
        "be updated still requires it."
    ),
    "Sticky Keys (5x Shift)": (
        "Pressing Shift five times in rapid succession normally triggers the Sticky Keys "
        "accessibility dialog. Disable this if accidental activation interrupts your workflow."
    ),
    "Storage Sense": (
        "Automatically removes temporary files, empties the Recycle Bin, and clears old "
        "Downloads folder items on a configured schedule."
    ),
    "Unknown Networks Profile": (
        "Sets the network profile assigned when Windows encounters an unrecognized "
        "connection. Public restricts discovery and sharing on unknown networks."
    ),
    "Updates for Other MS Products": (
        "Extends Windows Update to service other Microsoft software. Equivalent to enabling "
        'the "Receive updates for other Microsoft products" option in Update settings.'
    ),
    "Windows Update Repair": (
        "Resets the Windows Update stack: stops services, clears the download cache, "
        "re-registers DLLs, and resets BITS jobs. Aggressive mode adds DISM health checks "
        "and SFC scans."
    ),
    "Microsoft Store App Auto-Download": (
        "Controls whether the Store automatically downloads and installs app updates in "
        "the background. Disabling pauses Store updates until you check manually."
    ),
    "Verbose Startup/Shutdown Messages": (
        "Replaces the generic boot animation with descriptive status messages showing "
        "which services and scripts are starting or stopping."
    ),
    "Win32 Long Path Limit": (
        "Removes the 260-character file path limit for Win32 applications by setting "
        "LongPathsEnabled in the system registry. Also requires app manifests to opt in."
    ),
    "Windows Capabilities": (
        "Opens the optional features dialog for adding or removing Windows capabilities "
        "such as language packs, RSAT tools, and handwriting recognition. "
        "Some capabilities require internet access or a restart to complete."
    ),
    "Windows Features": (
        "Opens the Windows Features dialog for enabling or disabling built-in OS "
        "components like Hyper-V, Telnet, or TFTP. Changes take effect after a restart."
    ),
    "Legacy Media": (
        "Installs or removes the Windows Media Player, Media Features, DirectPlay, and "
        "Legacy Components feature bundle. Needed for older games and applications that "
        "depend on these components."
    ),
    "NFS": (
        "Installs NFS client support and writes the client configuration defaults. "
        "Enables mounting remote NFS exports as drive letters."
    ),
    "Hyper-V Management Tools": (
        "Installs the Hyper-V Manager console and PowerShell cmdlets without enabling the "
        "hypervisor itself. Lets you manage remote Hyper-V hosts without hosting VMs locally."
    ),
    "Windows Manage Default Printer": (
        "When enabled, Windows automatically promotes the most recently used printer to "
        "default. Disabling this keeps your manually selected default printer fixed."
    ),

    # === SystemTweaks.json ===
    "SMB Guest Authentication": (
        "Guest authentication for SMB has been blocked by default since Windows 10 1709 "
        "because it allows unauthenticated access to shares. Enable only for compatibility "
        "with legacy NAS devices or printers that do not support authenticated SMB."
    ),
    "Performance Tuning": (
        "Applies a set of legacy boot configuration flags and system responsiveness tweaks "
        "that were commonly recommended for older hardware. Benefit on modern SSDs and "
        "current Windows builds is minimal."
    ),
    "Repair Windows 11 SMB Issue": (
        "Patches a known Windows 11 regression where SMB share access fails after a "
        "specific update due to a missing registry value."
    ),
    "SMB Guest Compatibility": (
        "Re-enables unauthenticated SMB guest connections for compatibility with older "
        "network devices that do not support credential-based SMB. Creates a lateral "
        "movement risk on shared networks."
    ),
    "SMB Sharing Compatibility": (
        "Preserves existing share mappings and saved credentials when network-related "
        "tweaks are applied. Prevents those tweaks from inadvertently clearing your "
        "share configuration."
    ),
    "Repair Shared Printer Connection Errors": (
        "Aligns RPC, SMB, Point and Print, spooler, TCP, and network discovery settings "
        "to fix common shared printer connection failures. Requires a restart to take "
        "full effect."
    ),
    "Adobe Network Block": (
        "Adds outbound firewall rules blocking Adobe applications from reaching the "
        "internet. Breaks license validation, cloud document sync, and Creative Cloud "
        "updates — plan for manual license management before enabling."
    ),
    "Brave Debloat": (
        "Disables Brave Rewards, the crypto wallet, the built-in VPN, and the Leo AI "
        "assistant via policy keys. Does not affect browsing, sync, or extensions."
    ),
    "Cross-Device Resume": (
        "Enables a notification that lets you pick up tasks started on another Windows "
        "device. Requires a Microsoft account and cross-device activity sharing."
    ),
    "Disk Cleanup": (
        "Runs cleanmgr with all standard cleanup categories selected to remove temporary "
        "files, Windows Update leftovers, system cache, and other reclaimable data."
    ),
    "Explorer Automatic Folder Discovery": (
        "When enabled, File Explorer detects folder contents and applies a matching view "
        "template (Documents, Pictures, Music, etc.). Disabling uses a generic view for "
        "every folder and can speed up folder opens in large directories."
    ),
    "Modern Standby Fix": (
        "Modern Standby (S0) keeps the CPU and network active during sleep, which can "
        "drain battery and heat the chassis. This fix registers an S3-style deep sleep "
        "state where the hardware fully powers down."
    ),
    "Razer Software Block": (
        "Prevents Razer Synapse installation scripts from running automatically when Razer "
        "hardware is plugged in. Razer devices will still function at a basic level "
        "without Synapse."
    ),
    "S3 Sleep": (
        "S3 fully powers down components during sleep, giving true low-power standby. "
        "Some modern systems default to Modern Standby (S0) which keeps the CPU active "
        "and can cause unexpected battery drain."
    ),
    "Services Manual Startup": (
        "Converts a set of non-critical services from Automatic to Manual startup. "
        "Services remain available and will start on demand — they just do not start "
        "proactively at boot."
    ),
    "Teredo": (
        "Teredo tunnels IPv6 over UDP to reach IPv6-only destinations from IPv4 networks. "
        "Required for Xbox Live connectivity and some P2P applications. Disabling it will "
        "break those use cases."
    ),
    "Windows Platform Binary Table (WPBT)": (
        "WPBT is a UEFI firmware table that can instruct Windows to run a vendor binary "
        "early in startup. Disabling it prevents manufacturer-injected executables from "
        "running automatically, at the cost of potentially losing vendor management software."
    ),

    # === UWPApps.json ===
    "Background Apps": (
        "When disabled, UWP apps do not receive updates, notifications, or trigger "
        "background tasks while not in the foreground. Live tile data and push "
        "notifications will stop refreshing."
    ),
    "Copilot App": (
        "Removes Copilot, Recall, and the related Windows AI component packages. "
        "Reinstallation requires winget or Microsoft Store access."
    ),
    "Cortana Autostart": (
        "Prevents Cortana from registering a startup entry. Cortana can still be launched "
        "manually; this only stops it from starting automatically with Windows."
    ),
    "Edge Debloat": (
        "Writes Group Policy values to disable Edge telemetry, the shopping assistant, "
        "Collections, the Copilot sidebar, and other optional features. "
        "Does not affect browsing, sync, or extensions."
    ),
    "New Outlook": (
        "Removes or disables the new Outlook (formerly Mail & Calendar) app. "
        "Disabling reverts to the classic Win32 Outlook or Mail app."
    ),
    "Notifications": (
        "Disables the entire Windows notification system. No app will be able to deliver "
        "toasts or badge updates, and the Action Center will be empty."
    ),
    "Revert Start Menu (24H2)": (
        "Rolls back the Start Menu layout introduced in Windows 11 24H2. "
        "Applied via a registry key that may be reset by future Windows updates."
    ),
    "UWP Apps (Bulk)": (
        "Opens a selection dialog to remove or restore Store apps in bulk. "
        "Some removals are one-way or require winget, Microsoft Store, or manual "
        "reinstall to reverse."
    ),
}


def update_entries(obj):
    changed = 0
    if isinstance(obj, list):
        for item in obj:
            changed += update_entries(item)
    elif isinstance(obj, dict):
        if 'WhyThisMatters' in obj:
            name = obj.get('Name', '')
            if name in REWRITES:
                old = obj['WhyThisMatters']
                new = REWRITES[name]
                if old != new:
                    obj['WhyThisMatters'] = new
                    changed += 1
        else:
            for v in obj.values():
                changed += update_entries(v)
    return changed


FILES = [
    'Defender.json',
    'OSHardening.json',
    'PrivacyTelemetry.json',
    'System.json',
    'SystemTweaks.json',
    'UWPApps.json',
]

total_changed = 0
for fname in FILES:
    path = os.path.join(BASE, fname)
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    n = update_entries(data)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{fname}: {n} entries updated')
    total_changed += n

print(f'Total: {total_changed} entries updated')
