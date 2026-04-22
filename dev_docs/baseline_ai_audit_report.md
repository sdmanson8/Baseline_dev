# Baseline upload audit (excluding locale files)

Audited **225** text-based entries from the session, including text content extracted from non-locale archives. 
Excluded: locale pack and locale-support artifacts (`Localizations(2).zip`, `locale-map.json`, `localization_schema.json`, `string_length_limits.json`, `english_exempt_keys.json`), plus binary images/fonts.

This report does **not** claim authorship. It flags lines that **look AI-assisted or machine-generated** based on style: repetitive boilerplate, formulaic risk prose, marketing copy, or wrapper scaffolding.

## Overall conclusion

- The codebase does **not** look uniformly AI-written.

- The strongest AI-like signals are in **docs/marketing text**, **manifest JSON prose**, and **generic PowerShell docblocks**.

- Most application catalog JSON files look **templated/generated**, but **not strongly AI-specific**.

- The hardest files are large UI/orchestration PowerShell modules, but even those are **not beyond a typical programmer with 10+ years of experience**. They are broad and stateful, not algorithmically exotic.


## Complexity answer

- **Not every file is too complex.** Most files are low-to-medium complexity.

- Files that are genuinely hard because of state/threading/runspace/WPF scope: `RemoteTarget.Helpers.ps1`, `DialogHelpers.ps1`, `AppsModule.ps1`, `ExecutionOrchestration.ps1`, `Environment.Helpers.ps1`, `Applications.psm1`, `UWPApps.psm1`, `GUI.psm1`, `GUIExecution.psm1`, `PackageManagement.Helpers.ps1`, `PresetManagement.ps1`.

- Typical 10+ year programmers should be able to understand nearly all of this code with time; the pain points are **surface area, coupling, PowerShell module scope, runspaces, and WPF dispatcher behavior**.

## Files with strongest AI-like signals

### Defender.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 67: "WhyThisMatters": "SmartScreen checks downloaded files and apps against a cloud reputation database and warns you bef... | 102: "WhyThisMatters": "Controls whether Windows automatically enters recovery mode after consecutive failed boot attempts... | 137: "WhyThisMatters": "Hypervisor-protected code integrity runs Windows kernel code in a virtualized environment to preve... | 241: "WhyThisMatters": "Applies additional Exploit Guard attack surface reduction rules via Windows Defender to block comm... | 639: "WhyThisMatters": "Downloads and imports a pre-built exploit mitigation policy file into Windows Defender Exploit Gua...


### OSHardening.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 67: "WhyThisMatters": "Sets the preferred SCHANNEL cipher suites to strong AES-256 and AES-128 variants. Ensures strong e... | 134: "WhyThisMatters": "Enables Diffie-Hellman, ECDH, and PKCS key exchange algorithms in SCHANNEL. Ensures forward-secure... | 203: "WhyThisMatters": "Forces .NET Framework 4.x and 2.x to use system-default TLS and strong cryptography. Prevents olde... | 611: "WhyThisMatters": "Applies a broad set of registry hardening values covering credential protection, UAC, NTLM, TCP/IP... | 645: "WhyThisMatters": "Applies a set of security policy settings for Adobe Reader DC including protected mode, protected ...


### PrivacyTelemetry.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 485: "WhyThisMatters": "Master toggle controlling whether apps can request access to your camera. Disabling prevents all a... | 554: "WhyThisMatters": "The DiagTrack service collects and uploads Windows usage and diagnostic data to Microsoft servers.... | 663: "WhyThisMatters": "Several scheduled tasks run in the background to collect and upload diagnostic data. Disabling sto...


### README(2).md

- Complexity: Low

- AI-like signal: High (medium)

- Why: marketing/product-language

- Example lines: 10: <strong>Controlled, auditable Windows configuration for power users and IT professionals.</strong> | 81: Most Windows tweak repos optimize for either maximum aggression or maximum simplicity. Baseline optimizes for **trust**: | 90: The goal is not to strip Windows as aggressively as possible. The goal is to give power users a controlled, auditable...


### System.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 67: "WhyThisMatters": "Windows can silently install suggested apps in the background without asking you. Disabling stops ... | 150: "WhyThisMatters": "Controls how User Account Control behaves when an app requests elevated privileges. Available leve... | 286: "WhyThisMatters": "The Microsoft Networks client that allows this PC to access files and printers shared by other Win...


### SystemTweaks.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 67: "WhyThisMatters": "Runs a set of legacy system optimizations and boot configuration adjustments to improve general sy... | 133: "WhyThisMatters": "Allows SMB connections to network shares without requiring authentication. Needed for accessing ol... | 167: "WhyThisMatters": "Preserves your existing SMB share configuration and saved network credentials when other network t... | 237: "WhyThisMatters": "Adds firewall rules to block Adobe applications from accessing the internet. This affects license ... | 271: "WhyThisMatters": "Disables Brave browser's optional extras: rewards, crypto wallet, VPN, and AI chat. Only affects t...


### UWPApps.json

- Complexity: Low (data)

- AI-like signal: High (medium)

- Why: formulaic risk prose

- Example lines: 34: "WhyThisMatters": "Controls whether apps are allowed to run and update in the background when they are not in focus. ... | 140: "WhyThisMatters": "Applies Group Policy settings to disable telemetry, shopping assistant, collections, Copilot sideb... | 208: "WhyThisMatters": "Master switch for the entire Windows notification system. Disabling stops all app notifications an...


## Files with moderate AI-like signals

### Accessors.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 21: Internal implementation helper used by Baseline.


### ActionHandlers.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 353: Internal implementation helper used by Baseline. | 501: Internal implementation helper used by Baseline. | 570: Internal implementation helper used by Baseline.


### AdvancedStartup.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 26: Internal function . | 29: Internal implementation helper used by Baseline. | 55: Internal implementation helper used by Baseline.


### Applications.psm1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 11: Internal implementation helper used by Baseline. | 39: Internal implementation helper used by Baseline. | 67: Internal implementation helper used by Baseline.


### ApplicationsView.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 33: Internal implementation helper used by Baseline. | 50: Internal function . | 53: Internal implementation helper used by Baseline. | 111: Internal function .


### ApplyTheme.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline.


### AppsModule.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 9: Internal function . | 12: Internal implementation helper used by Baseline. | 117: Internal implementation helper used by Baseline. | 226: Internal implementation helper used by Baseline. | 1269: Internal function .


### AuditTrail.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline. | 26: Internal function . | 29: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 71: Internal function .


### AuditView.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 9: Internal implementation helper used by Baseline.


### Baseline(1).ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 170: Internal implementation helper used by Baseline. | 194: Internal implementation helper used by Baseline. | 218: Internal implementation helper used by Baseline.


### Bootstrap(1).ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 46: Internal implementation helper used by Baseline. | 75: Internal implementation helper used by Baseline. | 104: Internal implementation helper used by Baseline.


### BuildPrimaryTabs.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 272: Internal implementation helper used by Baseline.


### BuildTabContent.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline. | 122: Internal implementation helper used by Baseline. | 163: Internal implementation helper used by Baseline.


### BuildTweakControls.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 51: Internal implementation helper used by Baseline. | 178: Internal implementation helper used by Baseline. | 194: Internal function . | 197: Internal implementation helper used by Baseline.


### CliOutput.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 11: Internal implementation helper used by Baseline. | 34: Internal implementation helper used by Baseline. | 52: Internal function . | 55: Internal implementation helper used by Baseline.


### Compliance.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 16: Internal implementation helper used by Baseline. | 229: Internal implementation helper used by Baseline. | 254: Internal function . | 257: Internal implementation helper used by Baseline.


### ComplianceView.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline.


### ComponentFactory.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 362: Internal implementation helper used by Baseline. | 443: Internal implementation helper used by Baseline. | 540: Internal function .


### ConfigProfile.Helpers.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 14: Internal implementation helper used by Baseline. | 132: Internal implementation helper used by Baseline. | 364: Internal implementation helper used by Baseline.


### ContentManagement.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 21: Internal function . | 24: Internal implementation helper used by Baseline. | 42: Internal implementation helper used by Baseline. | 236: Internal function .


### ContextMenu.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 832: Internal implementation helper used by Baseline.


### Cursors.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 42: Internal implementation helper used by Baseline. | 73: Internal implementation helper used by Baseline.


### Defender.CoreProtection.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 520: Internal implementation helper used by Baseline. | 661: Internal implementation helper used by Baseline. | 685: Internal implementation helper used by Baseline.


### Defender.Hardening.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 33: Internal implementation helper used by Baseline. | 331: Internal implementation helper used by Baseline.


### Defender.Policies.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 28: Internal implementation helper used by Baseline. | 675: Internal implementation helper used by Baseline.


### DialogHelpers.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 18: Internal implementation helper used by Baseline. | 133: Internal implementation helper used by Baseline. | 217: Internal implementation helper used by Baseline.


### Dialogs.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 229: Internal implementation helper used by Baseline. | 350: Internal implementation helper used by Baseline.


### DiffView.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline. | 215: Internal implementation helper used by Baseline. | 715: Internal implementation helper used by Baseline.


### DpiAwareness.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline.


### Environment.Helpers.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 41: Internal implementation helper used by Baseline. | 73: Internal implementation helper used by Baseline. | 85: Internal function . | 126: Internal function .


### ErrorHandling.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 54: Internal implementation helper used by Baseline. | 165: Internal implementation helper used by Baseline. | 191: Internal function .


### EventInfrastructure.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 93: Internal implementation helper used by Baseline. | 143: Internal implementation helper used by Baseline. | 192: Internal function .


### ExecutionOrchestration.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 38: Internal implementation helper used by Baseline. | 87: Internal implementation helper used by Baseline. | 98: Internal function .


### ExecutionSummary.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 72: Internal implementation helper used by Baseline. | 98: Internal implementation helper used by Baseline. | 1213: Internal function .


### ExecutionSummaryDialog(1).ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline.


### ExecutionSummaryDialog.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 12: Internal implementation helper used by Baseline.


### FeatureMaturity.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 50: Internal implementation helper used by Baseline. | 67: Internal implementation helper used by Baseline. | 106: Internal implementation helper used by Baseline.


### FilteringLogic.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 52: Internal implementation helper used by Baseline. | 93: Internal implementation helper used by Baseline.


### GUI.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 16: Internal implementation helper used by Baseline. | 40: Internal function . | 43: Internal implementation helper used by Baseline. | 68: Internal implementation helper used by Baseline. | 462: Internal function .


### GUIExecution.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 27: Internal function . | 30: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 104: Internal implementation helper used by Baseline. | 118: Internal function .


### GameMode.Helpers.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 15: Internal implementation helper used by Baseline. | 51: Internal implementation helper used by Baseline. | 79: Internal implementation helper used by Baseline. | 145: Internal function . | 599: Internal function .


### GameModeState.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 40: Internal implementation helper used by Baseline. | 65: Internal implementation helper used by Baseline. | 120: Internal function . | 153: Internal function .


### Gaming.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 33: Internal implementation helper used by Baseline. | 512: Internal implementation helper used by Baseline. | 1721: Internal implementation helper used by Baseline.


### GroupPolicy.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 22: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 116: Internal implementation helper used by Baseline.


### GuiContext.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 9: Internal implementation helper used by Baseline. | 144: Internal implementation helper used by Baseline. | 193: Internal implementation helper used by Baseline. | 319: Internal function . | 401: Internal function .


### IconFactory.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 54: Internal implementation helper used by Baseline. | 68: Internal function . | 71: Internal implementation helper used by Baseline.


### IconRegistry.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 63: Internal implementation helper used by Baseline. | 77: Internal function . | 80: Internal implementation helper used by Baseline.


### Interactive(1).ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 85: Internal implementation helper used by Baseline. | 114: Internal implementation helper used by Baseline. | 138: Internal implementation helper used by Baseline.


### Layout.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 78: Internal implementation helper used by Baseline. | 90: Internal implementation helper used by Baseline.


### Lifecycle.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 195: Internal implementation helper used by Baseline.


### Localization.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 68: Internal implementation helper used by Baseline. | 105: Internal implementation helper used by Baseline. | 151: Internal implementation helper used by Baseline. | 354: Internal function .


### Logging.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 61: Internal implementation helper used by Baseline. | 92: Internal implementation helper used by Baseline. | 125: Internal implementation helper used by Baseline. | 176: Internal function . | 551: Internal function .


### Manifest.Helpers.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 84: Internal implementation helper used by Baseline. | 844: Internal function .


### ModeState.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 12: Internal implementation helper used by Baseline. | 106: Internal implementation helper used by Baseline.


### NetworkCrypto.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 33: Internal implementation helper used by Baseline. | 176: Internal implementation helper used by Baseline.


### ObservableState.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline.


### OneDrive.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 39: Internal implementation helper used by Baseline. | 69: Internal implementation helper used by Baseline.


### OperatorPolicy.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline. | 51: Internal implementation helper used by Baseline. | 105: Internal implementation helper used by Baseline. | 123: Internal function . | 175: Internal function .


### PackageManagement.Helpers.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 21: Internal function . | 24: Internal implementation helper used by Baseline. | 51: Internal implementation helper used by Baseline. | 210: Internal function .


### Persistence.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 11: Internal implementation helper used by Baseline. | 45: Internal implementation helper used by Baseline. | 106: Internal implementation helper used by Baseline.


### PlanSummaryPanel.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline.


### PopupWindows.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 394: Internal implementation helper used by Baseline. | 470: Internal implementation helper used by Baseline.


### PostActions.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 24: Internal function . | 27: Internal implementation helper used by Baseline. | 55: Internal implementation helper used by Baseline. | 99: Internal implementation helper used by Baseline.


### PreflightChecks.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 9: Internal implementation helper used by Baseline. | 350: Internal implementation helper used by Baseline. | 460: Internal implementation helper used by Baseline. | 589: Internal function .


### Preset.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline. | 51: Internal implementation helper used by Baseline. | 73: Internal implementation helper used by Baseline.


### PresetApplication.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 24: Internal function . | 27: Internal implementation helper used by Baseline. | 114: Internal implementation helper used by Baseline.


### PresetManagement.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 35: Internal implementation helper used by Baseline. | 78: Internal implementation helper used by Baseline. | 703: Internal function . | 746: Internal function .


### PresetUI.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 50: Internal implementation helper used by Baseline. | 74: Internal implementation helper used by Baseline. | 899: Internal function .


### PreviewBuilders.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 349: Internal implementation helper used by Baseline. | 617: Internal implementation helper used by Baseline. | 651: Internal implementation helper used by Baseline.


### PrivacyTelemetry.PrivacySettings.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 263: Internal implementation helper used by Baseline. | 1082: Internal implementation helper used by Baseline. | 1431: Internal implementation helper used by Baseline.


### PrivacyTelemetry.SystemSettings.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 191: Internal implementation helper used by Baseline. | 902: Internal implementation helper used by Baseline.


### PrivacyTelemetry.TelemetryServices.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 31: Internal implementation helper used by Baseline. | 212: Internal implementation helper used by Baseline. | 273: Internal implementation helper used by Baseline. | 459: Internal function .


### Program.cs

- Complexity: Low

- AI-like signal: Medium (low)

- Why: uniform XML docs / polished sectioning

- Example lines: 35: /// <summary> | 48: /// <summary> | 106: /// <summary>


### Recovery.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline. | 236: Internal implementation helper used by Baseline.


### Registry.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 93: Internal implementation helper used by Baseline. | 111: Internal function . | 114: Internal implementation helper used by Baseline.


### RemoteTarget.Helpers.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 42: Internal implementation helper used by Baseline. | 79: Internal implementation helper used by Baseline. | 104: Internal implementation helper used by Baseline.


### RemoveWindowsAI(1).ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 223: Internal implementation helper used by Baseline. | 235: Internal function . | 238: Internal implementation helper used by Baseline. | 322: Internal implementation helper used by Baseline. | 334: Internal function .


### RiskDecisionDialog.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline.


### ScenarioMode.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 39: Internal implementation helper used by Baseline. | 103: Internal implementation helper used by Baseline. | 134: Internal implementation helper used by Baseline.


### Scheduler.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline. | 144: Internal implementation helper used by Baseline. | 180: Internal implementation helper used by Baseline.


### SettingsStore.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 48: Internal implementation helper used by Baseline. | 60: Internal implementation helper used by Baseline.


### SharedHelpers.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 85: Internal implementation helper used by Baseline. | 138: Internal implementation helper used by Baseline. | 191: Internal implementation helper used by Baseline.


### Start-BaselineElevated(1).ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 31: Internal implementation helper used by Baseline. | 54: Internal implementation helper used by Baseline.


### StartMenu.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 364: Internal implementation helper used by Baseline.


### StateCapture.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 14: Internal implementation helper used by Baseline. | 57: Internal implementation helper used by Baseline. | 105: Internal implementation helper used by Baseline.


### StateTransitions.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline.


### StyleManagement.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 13: Internal implementation helper used by Baseline. | 192: Internal implementation helper used by Baseline. | 305: Internal implementation helper used by Baseline. | 536: Internal function .


### StyledControlsSetup.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 73: Internal implementation helper used by Baseline. | 90: Internal function . | 93: Internal implementation helper used by Baseline.


### SupportBundle.Helpers.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 10: Internal implementation helper used by Baseline.


### System.FeatureBundles.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 100: Internal implementation helper used by Baseline. | 135: Internal implementation helper used by Baseline. | 176: Internal implementation helper used by Baseline.


### System.FileAssociations.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 33: Internal implementation helper used by Baseline. | 332: Internal implementation helper used by Baseline. | 497: Internal implementation helper used by Baseline. | 818: Internal function .


### System.Networking.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 184: Internal implementation helper used by Baseline. | 1051: Internal implementation helper used by Baseline.


### System.Power.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 31: Internal implementation helper used by Baseline. | 117: Internal implementation helper used by Baseline. | 227: Internal implementation helper used by Baseline.


### System.Updates.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 407: Internal implementation helper used by Baseline. | 606: Internal implementation helper used by Baseline. | 851: Internal implementation helper used by Baseline.


### System.Utilities.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 62: Internal implementation helper used by Baseline. | 104: Internal implementation helper used by Baseline. | 152: Internal implementation helper used by Baseline.


### System.WindowsFeatures.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 94: Internal implementation helper used by Baseline. | 264: Internal implementation helper used by Baseline. | 295: Internal implementation helper used by Baseline. | 378: Internal function . | 1229: Internal function .


### System.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 233: Internal implementation helper used by Baseline. | 1209: Internal implementation helper used by Baseline.


### SystemMaintenance.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 43: Internal implementation helper used by Baseline. | 54: Internal function . | 57: Internal implementation helper used by Baseline.


### SystemOptimizations.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 11: Internal implementation helper used by Baseline. | 27: Internal function . | 30: Internal implementation helper used by Baseline. | 61: Internal implementation helper used by Baseline.


### SystemScan.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 15: Internal function . | 18: Internal implementation helper used by Baseline. | 46: Internal implementation helper used by Baseline.


### SystemTweaks.Cleanup.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 165: Internal implementation helper used by Baseline.


### SystemTweaks.General.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 28: Internal implementation helper used by Baseline. | 154: Internal implementation helper used by Baseline.


### SystemTweaks.HardwarePower.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 34: Internal implementation helper used by Baseline. | 446: Internal implementation helper used by Baseline.


### SystemTweaks.SMBRepair.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 35: Internal implementation helper used by Baseline. | 79: Internal implementation helper used by Baseline. | 121: Internal implementation helper used by Baseline.


### TabManagement.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 38: Internal implementation helper used by Baseline. | 80: Internal implementation helper used by Baseline. | 192: Internal function .


### Taskbar.Helpers.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 37: Internal implementation helper used by Baseline. | 75: Internal implementation helper used by Baseline.


### Taskbar.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 9: Internal implementation helper used by Baseline. | 33: Internal implementation helper used by Baseline. | 111: Internal implementation helper used by Baseline.


### ThemeManagement.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 128: Internal implementation helper used by Baseline. | 168: Internal implementation helper used by Baseline. | 193: Internal implementation helper used by Baseline.


### TweakAnalysis.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 42: Internal implementation helper used by Baseline. | 81: Internal implementation helper used by Baseline. | 272: Internal function .


### TweakVisualization.ps1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 8: Internal implementation helper used by Baseline. | 365: Internal implementation helper used by Baseline. | 507: Internal implementation helper used by Baseline. | 525: Internal function . | 819: Internal function .


### UIPersonalization.Appearance.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 181: Internal implementation helper used by Baseline.


### UIPersonalization.Explorer.psm1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 282: Internal implementation helper used by Baseline. | 1678: Internal implementation helper used by Baseline. | 2008: Internal implementation helper used by Baseline.


### UIPersonalization.Icons.psm1

- Complexity: Medium

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 958: Internal implementation helper used by Baseline.


### UIPersonalization.LockScreen.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 122: Internal implementation helper used by Baseline. | 230: Internal function . | 233: Internal implementation helper used by Baseline. | 296: Internal function . | 299: Internal implementation helper used by Baseline.


### UIPersonalization.psm1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 42: Internal implementation helper used by Baseline. | 132: Internal implementation helper used by Baseline.


### UWPApps.psm1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 104: Internal implementation helper used by Baseline. | 342: Internal implementation helper used by Baseline. | 522: Internal implementation helper used by Baseline. | 1367: Internal function . | 2363: Internal function .


### UpdateOverlayModule.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 12: Internal implementation helper used by Baseline. | 37: Internal implementation helper used by Baseline. | 91: Internal implementation helper used by Baseline. | 234: Internal function .


### Utilities.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 51: Internal implementation helper used by Baseline. | 117: Internal implementation helper used by Baseline.


### UxPolicy.ps1

- Complexity: High

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 14: Internal implementation helper used by Baseline. | 24: Internal function . | 27: Internal implementation helper used by Baseline. | 36: Internal function . | 39: Internal implementation helper used by Baseline.


### WindowChrome.ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 6: Internal implementation helper used by Baseline. | 74: Internal implementation helper used by Baseline. | 127: Internal implementation helper used by Baseline.


### diskcleanup(1).ps1

- Complexity: Low

- AI-like signal: Medium (medium)

- Why: generic boilerplate docblocks

- Example lines: 63: Internal implementation helper used by Baseline. | 76: Internal function . | 79: Internal implementation helper used by Baseline. | 132: Internal implementation helper used by Baseline.


## Files with low or no strong AI-like signals

### Advanced.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### Balanced.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### Baseline.SharedHelpers.AdvancedStartup.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for AdvancedStartup.Helpers.ps1.


### Baseline.SharedHelpers.AuditTrail.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for AuditTrail.Helpers.ps1.


### Baseline.SharedHelpers.CliOutput.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for CliOutput.Helpers.ps1.


### Baseline.SharedHelpers.Compliance.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Compliance.Helpers.ps1.


### Baseline.SharedHelpers.ConfigProfile.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for ConfigProfile.Helpers.ps1.


### Baseline.SharedHelpers.Environment.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Environment.Helpers.ps1.


### Baseline.SharedHelpers.ErrorHandling.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for ErrorHandling.Helpers.ps1.


### Baseline.SharedHelpers.FeatureMaturity.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for FeatureMaturity.Helpers.ps1.


### Baseline.SharedHelpers.GameMode.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for GameMode.Helpers.ps1.


### Baseline.SharedHelpers.GroupPolicy.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for GroupPolicy.Helpers.ps1.


### Baseline.SharedHelpers.InitialActions.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for InitialActions.Helpers.ps1.


### Baseline.SharedHelpers.Integrity.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Integrity.Helpers.ps1.


### Baseline.SharedHelpers.Json.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Json.Helpers.ps1.


### Baseline.SharedHelpers.Lifecycle.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Lifecycle.Helpers.ps1.


### Baseline.SharedHelpers.Localization.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Localization.Helpers.ps1.


### Baseline.SharedHelpers.Manifest.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Manifest.Helpers.ps1.


### Baseline.SharedHelpers.OperatorPolicy.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for OperatorPolicy.Helpers.ps1.


### Baseline.SharedHelpers.PackageManagement.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for PackageManagement.Helpers.ps1.


### Baseline.SharedHelpers.Persistence.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Persistence.Helpers.ps1.


### Baseline.SharedHelpers.Preset.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Preset.Helpers.ps1.


### Baseline.SharedHelpers.Recovery.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Recovery.Helpers.ps1.


### Baseline.SharedHelpers.Registry.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Registry.Helpers.ps1.


### Baseline.SharedHelpers.ScenarioMode.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for ScenarioMode.Helpers.ps1.


### Baseline.SharedHelpers.Scheduler.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Scheduler.Helpers.ps1.


### Baseline.SharedHelpers.StateCapture.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for StateCapture.Helpers.ps1.


### Baseline.SharedHelpers.SupportBundle.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for SupportBundle.Helpers.ps1.


### Baseline.SharedHelpers.SystemMaintenance.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for SystemMaintenance.Helpers.ps1.


### Baseline.SharedHelpers.Taskbar.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for Taskbar.Helpers.ps1.


### Baseline.SharedHelpers.WindowsFeatures.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: wrapper-scaffold wording

- Example lines: 3: Wrapper module for WindowsFeatures.Helpers.ps1.


### Baseline.psd1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Baseline.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Basic.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### Browsers.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### CHANGELOG(2).md

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Communication.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### Compression.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### ContextMenu.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Cursors.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Defender.Firewall.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Defender.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### DetectScriptblocks.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Development.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### Documents.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### Errors.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### FAQ(2).md

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### FileManagement.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### GUICommon.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### GameModeAdvanced.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### GameModeAllowlist.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### GameModeProfiles.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### Gaming(1).json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### Gaming.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Imaging.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### InitialActions.Helpers.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### InitialActions.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### InitialSetup.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### InitialSetup.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Integrity.Helpers.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Json.Helpers.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### MainWindow.xaml

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Media.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### Minimal.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: list/preset data


### OSHardening.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### OneDrive.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### PrivacyTelemetry.UWPPermissions.psm1

- Complexity: Medium

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### PrivacyTelemetry.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### ProtectionHardening.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### RemoteAccess.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### RunLauncher.csproj

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Runtimes.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### SearchFilterHandlers.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Security.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### StartMenu.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### StartMenuApps.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### StartMenuApps.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### System.SystemMisc.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### SystemTweaks.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Taskbar.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### TaskbarClock.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### TaskbarClock.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### UIPersonalization.Notifications.psm1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### UIPersonalization.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Updates.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### Utilities.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: templated catalog data (not strong AI evidence)


### WindowSetup.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### WindowsFeatures.Helpers.ps1

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [github-pages.zip] ./google906d6ac91b49de74.html

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [github-pages.zip] ./index.html

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [github-pages.zip] ./sitemap.xml

- Complexity: Low

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-server-2022.zip] DesktopMatrixResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-server-2022.zip] IntegrationResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-win10-22h2.zip] DesktopMatrixResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-win10-22h2.zip] IntegrationResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-win11-24h2.zip] DesktopMatrixResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal


### [integration-report-win11-24h2.zip] IntegrationResults.json

- Complexity: Low (data)

- AI-like signal: Low (low)

- Why: no strong AI-specific signal

