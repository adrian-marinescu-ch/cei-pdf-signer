# Mobile eID Reader - Technical Specification

A comprehensive guide for building Android and iOS applications to read Romanian Electronic Identity Cards (CEI) via NFC.

---

## Table of Contents

1. [Overview](#overview)
2. [Romanian CEI Card Specifications](#romanian-cei-card-specifications)
3. [Authentication Flow](#authentication-flow)
4. [Data Groups (What Can Be Read)](#data-groups-what-can-be-read)
5. [Android Implementation](#android-implementation)
6. [iOS Implementation](#ios-implementation)
7. [Common Architecture](#common-architecture)
8. [Security Considerations](#security-considerations)
9. [Known Limitations](#known-limitations)
10. [References & Resources](#references--resources)

---

## Overview

### Goal

Build native mobile applications (Android + iOS) that can:
1. Read personal data from Romanian Electronic Identity Cards (CEI) via NFC
2. Authenticate using CAN (Card Access Number) and PIN
3. Display extracted information (name, CNP, photo, address, etc.)
4. Optionally export data to PDF

### Why Native Apps?

- NFC access requires low-level platform APIs
- Existing proven libraries (JMRTD for Android, NFCPassportReader for Swift)
- Better reliability for cryptographic operations
- React Native/Flutter NFC support is less mature for eID reading

---

## Romanian CEI Card Specifications

### Card Overview

| Property | Value |
|----------|-------|
| Launch Date | March 20, 2025 (Cluj), June 2025 (nationwide) |
| Standards | ICAO 9303, EU eID, BSI TR-03110 |
| Chip Type | Dual-interface (contact + contactless/NFC) |
| NFC Frequency | 13.56 MHz (ISO 14443) |
| Biometrics | Face photo, 2 fingerprints |
| Certificates | Authentication + Advanced Electronic Signature |

### Printed Information (Visible on Card)

- Full name
- Date of birth
- Gender
- Nationality (Romanian)
- CNP (Personal Numeric Code - 13 digits)
- Card number
- Issue/expiry dates
- Photo
- CAN (Card Access Number) - 6 digits on front

### Chip Contents

| Data Group | Content | Access Level |
|------------|---------|--------------|
| DG1 | MRZ data (name, DOB, document number, etc.) | PACE + PIN |
| DG2 | Facial image (JPEG2000, ~15KB) | PACE + PIN |
| DG3 | Fingerprints (2) | EAC (restricted) |
| DG5 | Portrait image | PACE + PIN |
| DG7 | Displayed signature | PACE + PIN |
| DG11 | Additional personal details (parents, address) | PACE + PIN |
| DG13 | Optional details | PACE + PIN |
| DG14 | Security infos for EAC | PACE |
| DG15 | Active Authentication public key | PACE |

### PINs

| PIN Type | Digits | Purpose |
|----------|--------|---------|
| CAN | 6 | Card Access Number - printed on card, used for PACE |
| Auth PIN | 4 | Authentication to online services |
| Sign PIN | 6 | Digital signature operations |
| PUK | 8 | Unlock blocked PINs |

---

## Authentication Flow

### Protocol: PACE (Password Authenticated Connection Establishment)

Romanian CEI uses **PACE** protocol (successor to BAC - Basic Access Control). PACE provides:
- Secure channel establishment
- Protection against eavesdropping
- Mutual authentication

### Step-by-Step Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User      │     │   App       │     │  CEI Card   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ 1. Enter CAN      │                   │
       │──────────────────>│                   │
       │                   │                   │
       │ 2. Enter PIN      │                   │
       │──────────────────>│                   │
       │                   │                   │
       │ 3. Tap card       │                   │
       │──────────────────>│                   │
       │                   │                   │
       │                   │ 4. Read EF.CardAccess
       │                   │──────────────────>│
       │                   │<──────────────────│
       │                   │   (PACE params)   │
       │                   │                   │
       │                   │ 5. PACE with CAN  │
       │                   │<─────────────────>│
       │                   │  (secure channel) │
       │                   │                   │
       │                   │ 6. Verify PIN     │
       │                   │──────────────────>│
       │                   │<──────────────────│
       │                   │   (success/fail)  │
       │                   │                   │
       │                   │ 7. Read DG1, DG2..│
       │                   │──────────────────>│
       │                   │<──────────────────│
       │                   │   (encrypted data)│
       │                   │                   │
       │ 8. Display data   │                   │
       │<──────────────────│                   │
       │                   │                   │
```

### PACE Variants

| Variant | Support | Notes |
|---------|---------|-------|
| PACE-GM (General Mapping) | ✅ Required | Supported by all libraries |
| PACE-IM (Integrated Mapping) | ⚠️ Optional | Limited library support |
| PACE-CAM (Chip Auth Mapping) | ⚠️ Optional | Limited library support |

**Important**: Romanian CEI should support PACE-GM. If implementation issues occur, check card's EF.CardAccess for supported variants.

---

## Data Groups (What Can Be Read)

### DG1 - Machine Readable Zone (MRZ) Data

```
Fields available:
- Document type (ID)
- Issuing country (ROU)
- Surname
- Given names
- Document number
- Nationality
- Date of birth
- Sex (M/F)
- Expiry date
- Personal number (CNP)
```

### DG2 - Facial Image

- Format: JPEG2000 or JPEG
- Size: ~15-20 KB
- Resolution: Typically 300+ DPI equivalent

### DG11 - Additional Personal Details

```
Fields may include:
- Full name (extended)
- Other names
- Personal number
- Place of birth
- Address/Residence
- Telephone
- Profession
- Title
- Personal summary
- Custody information
```

### Parsing Libraries

Both Android (JMRTD) and iOS (NFCPassportReader) provide classes to parse these data groups into structured objects.

---

## Android Implementation

### Dependencies (build.gradle)

```groovy
dependencies {
    // JMRTD - Core eID/passport reading library
    implementation 'org.jmrtd:jmrtd:0.7.42'

    // SCUBA - Smart Card Utils (required by JMRTD)
    implementation 'net.sf.scuba:scuba-sc-android:0.0.26'

    // Bouncy Castle - Crypto provider
    implementation 'org.bouncycastle:bcprov-jdk18on:1.78'
    implementation 'org.bouncycastle:bcpkix-jdk18on:1.78'

    // Image decoding (for JPEG2000 in DG2)
    implementation 'com.gemalto.jp2:jp2-android:1.0.3'
    // Alternative: implementation 'org.apache.commons:commons-imaging:1.0-alpha3'
}
```

### Minimum SDK

```groovy
android {
    defaultConfig {
        minSdkVersion 21  // NFC available from API 21
        targetSdkVersion 34
    }
}
```

### AndroidManifest.xml

```xml
<manifest>
    <!-- NFC Permission -->
    <uses-permission android:name="android.permission.NFC" />

    <!-- Require NFC hardware -->
    <uses-feature
        android:name="android.hardware.nfc"
        android:required="true" />

    <application>
        <activity android:name=".MainActivity">
            <!-- NFC Intent Filter -->
            <intent-filter>
                <action android:name="android.nfc.action.TECH_DISCOVERED" />
            </intent-filter>

            <meta-data
                android:name="android.nfc.action.TECH_DISCOVERED"
                android:resource="@xml/nfc_tech_filter" />
        </activity>
    </application>
</manifest>
```

### res/xml/nfc_tech_filter.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <tech-list>
        <tech>android.nfc.tech.IsoDep</tech>
    </tech-list>
</resources>
```

### Core Reading Code (Kotlin)

```kotlin
import android.nfc.Tag
import android.nfc.tech.IsoDep
import net.sf.scuba.smartcards.CardService
import org.jmrtd.PassportService
import org.jmrtd.lds.icao.DG1File
import org.jmrtd.lds.icao.DG2File
import org.jmrtd.PACEKeySpec
import org.jmrtd.BACKey

class EidReader {

    fun readCard(
        tag: Tag,
        can: String,      // 6-digit CAN from card
        pin: String       // 4-digit auth PIN
    ): EidData {
        val isoDep = IsoDep.get(tag)
        isoDep.timeout = 10000  // 10 seconds
        isoDep.connect()

        val cardService = CardService.getInstance(isoDep)
        val passportService = PassportService(
            cardService,
            PassportService.NORMAL_MAX_TRANCEIVE_LENGTH,
            PassportService.DEFAULT_MAX_BLOCKSIZE,
            false,  // isSFIEnabled
            true    // checkMAC
        )
        passportService.open()

        try {
            // Step 1: Perform PACE with CAN
            val paceKeySpec = PACEKeySpec.createCANKey(can)
            passportService.doPACE(
                paceKeySpec,
                null,  // oid (auto-detect from EF.CardAccess)
                null,  // parameterId (auto-detect)
                null   // parameterId (auto-detect)
            )

            // Step 2: Verify PIN (if required for data access)
            // Note: PIN verification may use different APDU
            // This depends on Romanian CEI implementation
            // passportService.doBAC(BACKey(pin, ...)) // if BAC fallback needed

            // Step 3: Read DG1 (personal data)
            val dg1Stream = passportService.getInputStream(PassportService.EF_DG1)
            val dg1 = DG1File(dg1Stream)
            val mrzInfo = dg1.mrzInfo

            // Step 4: Read DG2 (photo)
            val dg2Stream = passportService.getInputStream(PassportService.EF_DG2)
            val dg2 = DG2File(dg2Stream)
            val faceImages = dg2.faceInfos

            // Step 5: Read DG11 (additional details) if available
            // val dg11Stream = passportService.getInputStream(PassportService.EF_DG11)
            // val dg11 = DG11File(dg11Stream)

            return EidData(
                surname = mrzInfo.primaryIdentifier,
                givenNames = mrzInfo.secondaryIdentifierComponents.joinToString(" "),
                documentNumber = mrzInfo.documentNumber,
                nationality = mrzInfo.nationality,
                dateOfBirth = mrzInfo.dateOfBirth,
                sex = mrzInfo.gender.toString(),
                expiryDate = mrzInfo.dateOfExpiry,
                personalNumber = mrzInfo.personalNumber,  // CNP
                photo = faceImages.firstOrNull()?.imageInputStream?.readBytes()
            )

        } finally {
            passportService.close()
        }
    }
}

data class EidData(
    val surname: String,
    val givenNames: String,
    val documentNumber: String,
    val nationality: String,
    val dateOfBirth: String,
    val sex: String,
    val expiryDate: String,
    val personalNumber: String,  // CNP
    val photo: ByteArray?
)
```

### NFC Activity Handling

```kotlin
class MainActivity : AppCompatActivity() {

    private lateinit var nfcAdapter: NfcAdapter
    private var pendingIntent: PendingIntent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_MUTABLE
        )
    }

    override fun onResume() {
        super.onResume()
        nfcAdapter.enableForegroundDispatch(
            this,
            pendingIntent,
            arrayOf(IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)),
            arrayOf(arrayOf(IsoDep::class.java.name))
        )
    }

    override fun onPause() {
        super.onPause()
        nfcAdapter.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        if (NfcAdapter.ACTION_TECH_DISCOVERED == intent.action) {
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            tag?.let { processTag(it) }
        }
    }

    private fun processTag(tag: Tag) {
        // Run in background thread
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val can = "123456"  // Get from user input
                val pin = "1234"    // Get from user input

                val reader = EidReader()
                val data = reader.readCard(tag, can, pin)

                withContext(Dispatchers.Main) {
                    displayData(data)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    showError(e.message)
                }
            }
        }
    }
}
```

### Proguard Rules (proguard-rules.pro)

```proguard
# JMRTD
-keep class org.jmrtd.** { *; }
-keep class net.sf.scuba.** { *; }

# Bouncy Castle
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
```

---

## iOS Implementation

### Requirements

| Requirement | Value |
|-------------|-------|
| iOS Version | 13.0+ (CoreNFC with ISO7816) |
| Device | iPhone 7 or later |
| Xcode | 12+ |
| Swift | 5.0+ |

### Library: NFCPassportReader

Add to Package.swift or via Xcode:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/AndyQ/NFCPassportReader.git", from: "2.1.0")
]
```

Or via CocoaPods:

```ruby
# Podfile
pod 'NFCPassportReader'
```

### Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- NFC Usage Description (required) -->
    <key>NFCReaderUsageDescription</key>
    <string>Read your electronic identity card</string>

    <!-- eID/Passport Application ID -->
    <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
    <array>
        <string>A0000002471001</string>
    </array>

    <!-- PACE Support (required for PACE-only cards) -->
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>PACE</string>
        <string>TAG</string>
    </array>
</dict>
</plist>
```

### Entitlements (App.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>PACE</string>
        <string>TAG</string>
    </array>
</dict>
</plist>
```

### Core Reading Code (Swift)

```swift
import NFCPassportReader
import CoreNFC

class EidReaderViewModel: ObservableObject {

    @Published var eidData: EidData?
    @Published var error: String?
    @Published var isReading = false

    private var passportReader: PassportReader!

    func readCard(can: String, pin: String) {
        isReading = true
        error = nil

        // Create passport reader
        passportReader = PassportReader()

        // Configure for PACE with CAN
        // Note: MRZ key format for PACE-CAN may need adjustment
        // Romanian CEI uses CAN (6 digits) + PIN (4 digits)

        let mrzKey = can  // For PACE, we use CAN

        // Data groups to read
        let dataGroups: [DataGroupId] = [
            .DG1,   // Personal data
            .DG2,   // Photo
            .DG11   // Additional details (if available)
        ]

        // Custom PACE handler if needed
        passportReader.passportReaderHelper = self

        Task {
            do {
                let passport = try await passportReader.readPassport(
                    mrzKey: mrzKey,
                    tags: dataGroups,
                    pacePassword: can,
                    pacePasswordType: .CAN
                )

                await MainActor.run {
                    self.eidData = self.extractData(from: passport)
                    self.isReading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isReading = false
                }
            }
        }
    }

    private func extractData(from passport: NFCPassportModel) -> EidData {
        // Extract DG1 data
        let dg1 = passport.dataGroupsRead[.DG1] as? DataGroup1

        // Extract photo from DG2
        var photoData: Data?
        if let dg2 = passport.dataGroupsRead[.DG2] as? DataGroup2 {
            photoData = dg2.getImage()
        }

        return EidData(
            surname: dg1?.lastName ?? "",
            givenNames: dg1?.firstName ?? "",
            documentNumber: dg1?.documentNumber ?? "",
            nationality: dg1?.nationality ?? "",
            dateOfBirth: dg1?.dateOfBirth ?? "",
            sex: dg1?.gender ?? "",
            expiryDate: dg1?.documentExpiryDate ?? "",
            personalNumber: dg1?.personalNumber ?? "",  // CNP
            photo: photoData
        )
    }
}

struct EidData {
    let surname: String
    let givenNames: String
    let documentNumber: String
    let nationality: String
    let dateOfBirth: String
    let sex: String
    let expiryDate: String
    let personalNumber: String  // CNP
    let photo: Data?
}
```

### SwiftUI View

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EidReaderViewModel()

    @State private var can: String = ""
    @State private var pin: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // CAN Input
                TextField("CAN (6 digits)", text: $can)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // PIN Input
                SecureField("PIN (4 digits)", text: $pin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Read Button
                Button(action: {
                    viewModel.readCard(can: can, pin: pin)
                }) {
                    HStack {
                        Image(systemName: "wave.3.right")
                        Text(viewModel.isReading ? "Reading..." : "Read Card")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(can.count != 6 || pin.count != 4 || viewModel.isReading)

                // Results
                if let data = viewModel.eidData {
                    EidDataView(data: data)
                }

                // Error
                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("CEI Reader")
        }
    }
}

struct EidDataView: View {
    let data: EidData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let photoData = data.photo,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 120)
            }

            Text("Name: \(data.givenNames) \(data.surname)")
            Text("CNP: \(data.personalNumber)")
            Text("DOB: \(data.dateOfBirth)")
            Text("Expires: \(data.expiryDate)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
```

### iOS Gotchas

1. **NFC Session Timeout**: iOS NFC sessions have a ~60 second timeout. Reading multiple data groups may timeout.

2. **Background Reading**: NFC cannot run in background. App must be in foreground.

3. **Simulator**: NFC cannot be tested on simulator. Use real device.

4. **PACE Entitlement**: For PACE-only cards (no BAC), you need special entitlement that may require Apple approval.

5. **AID Selection**: The default AID `A0000002471001` works for most ePassports/eIDs. Romanian CEI should use this.

---

## Common Architecture

### Recommended App Structure

```
app/
├── ui/
│   ├── screens/
│   │   ├── HomeScreen          # CAN/PIN input
│   │   ├── ScanScreen          # NFC scanning UI
│   │   └── ResultScreen        # Display data
│   └── components/
│       ├── PinInput
│       └── EidDataCard
├── data/
│   ├── models/
│   │   └── EidData             # Data class
│   └── repository/
│       └── EidReader           # NFC reading logic
├── utils/
│   ├── DateParser              # Parse MRZ dates
│   └── ImageDecoder            # JPEG2000 decoder
└── di/
    └── AppModule               # Dependency injection
```

### UI Flow

```
┌──────────────────┐
│   Home Screen    │
│                  │
│  [CAN: ______]   │
│  [PIN: ____]     │
│                  │
│  [Read Card]     │
└────────┬─────────┘
         │
         v
┌──────────────────┐
│   Scan Screen    │
│                  │
│   ┌──────────┐   │
│   │  (card)  │   │
│   │   icon   │   │
│   └──────────┘   │
│                  │
│  "Hold card to   │
│   back of phone" │
│                  │
│  [Cancel]        │
└────────┬─────────┘
         │
         v
┌──────────────────┐
│  Result Screen   │
│                  │
│  ┌────┐          │
│  │foto│ Name     │
│  └────┘ CNP      │
│         DOB      │
│         ...      │
│                  │
│  [Export PDF]    │
│  [New Scan]      │
└──────────────────┘
```

---

## Security Considerations

### DO

- ✅ Clear PIN from memory immediately after use
- ✅ Use secure text input for PIN
- ✅ Validate CAN format (6 digits) before attempting
- ✅ Handle NFC errors gracefully
- ✅ Show clear feedback during reading
- ✅ Encrypt any stored data (if caching)

### DON'T

- ❌ Log or store PINs
- ❌ Transmit data to external servers (unless encrypted and necessary)
- ❌ Store biometric data (fingerprints from DG3)
- ❌ Attempt to read DG3 (fingerprints) - requires EAC and government certificates

### PIN Handling

```kotlin
// Android - Clear PIN after use
var pin: CharArray = charArrayOf('1', '2', '3', '4')
try {
    reader.readCard(tag, can, String(pin))
} finally {
    Arrays.fill(pin, '0')  // Zero out
}
```

```swift
// iOS - Clear PIN after use
var pin = "1234"
defer {
    pin = String(repeating: "0", count: pin.count)
}
viewModel.readCard(can: can, pin: pin)
```

---

## Known Limitations

### General

| Limitation | Description |
|------------|-------------|
| No signing | Mobile apps can only READ data, not sign documents |
| No fingerprints | DG3 (fingerprints) requires EAC with government certificates |
| NFC range | 1-4 cm effective range, phone case may interfere |
| Metal interference | Metal card holders block NFC |

### Android

| Limitation | Workaround |
|------------|------------|
| Some Samsung devices have weak NFC | Test positioning, remove case |
| JPEG2000 decoding | Use jp2-android or commons-imaging library |
| PACE-IM not supported by JMRTD | Use PACE-GM (should work with CEI) |

### iOS

| Limitation | Workaround |
|------------|------------|
| NFC session 60s timeout | Read essential DGs first (DG1, DG2) |
| No background NFC | Show clear instructions to keep app open |
| PACE entitlement may need Apple approval | Apply through developer portal |
| PACE-IM not supported | Use PACE-GM |

### Romanian CEI Specific

| Issue | Notes |
|-------|-------|
| New cards (2025) | May have different data structure, test thoroughly |
| CAN location | Printed on front of card (6 digits) |
| PIN vs CAN | CAN for PACE, PIN for authentication - different purposes |

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Tag was lost` | Card moved during reading | Instruct user to hold steady |
| `PACE failed` | Wrong CAN | Verify CAN digits |
| `PIN blocked` | 3 wrong PIN attempts | Use PUK to unblock (not in-app) |
| `Timeout` | Reading took too long | Read fewer DGs, retry |
| `SW 6300` | Authentication failed | Check CAN/PIN |
| `SW 6982` | Security status not satisfied | PACE not completed |
| `SW 6A82` | File not found | DG not present on card |

### User-Friendly Messages

```kotlin
fun getErrorMessage(e: Exception): String = when {
    e.message?.contains("Tag was lost") == true ->
        "Card moved. Please hold the card steady against your phone."
    e.message?.contains("PACE") == true ->
        "Authentication failed. Please check the CAN number."
    e.message?.contains("6300") == true ->
        "Wrong PIN. Please try again."
    e.message?.contains("timeout") == true ->
        "Reading timed out. Please try again."
    else ->
        "An error occurred. Please try again."
}
```

---

## Testing

### Test Checklist

- [ ] Valid CAN + PIN reads data successfully
- [ ] Invalid CAN shows appropriate error
- [ ] Invalid PIN shows appropriate error
- [ ] Card removed mid-read shows error
- [ ] Timeout handling works
- [ ] Photo decodes correctly
- [ ] All text fields display properly (diacritics: ă, î, ș, ț)
- [ ] Works with phone case on
- [ ] Works in portrait and landscape

### Test Devices

**Android** (recommended):
- Google Pixel 6+
- Samsung Galaxy S21+
- OnePlus 9+

**iOS** (recommended):
- iPhone 12+
- iPhone SE (2nd gen)+

---

## References & Resources

### Official Documentation

- [Romanian CEI Official Site](https://carteadeidentitate.gov.ro/)
- [MAI CEI Application](https://hub.mai.gov.ro/aplicatie-cei)
- [ICAO Doc 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303)
- [BSI TR-03110](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/Technische-Richtlinien/TR-nach-Thema-sortiert/tr03110/tr-03110.html)

### Libraries

**Android:**
- [JMRTD](https://jmrtd.org/) - Java MRTD library
- [SCUBA](https://scuba.sourceforge.net/) - Smart Card Utils
- [Bouncy Castle](https://www.bouncycastle.org/) - Crypto

**iOS:**
- [NFCPassportReader (AndyQ)](https://github.com/AndyQ/NFCPassportReader)
- [NFCPassportReader (andrea-deluca)](https://github.com/andrea-deluca/NFCPassportReader)

### Example Projects

- [AndroidPassportReader](https://github.com/jllarraz/AndroidPassportReader)
- [epassport-reader](https://github.com/Glamdring/epassport-reader)
- [passport-reader](https://github.com/tananaev/passport-reader)
- [cardreader (Ukrainian ID)](https://github.com/tkaczenko/cardreader)

### Articles

- [How To Read Your Passport With Android](https://techblog.bozho.net/how-to-read-your-passport-with-android/)
- [Reading Passports from a Phone](https://medium.com/jumio/reading-passports-from-a-phone-the-power-of-nfc-9ce67fdea2ed)

---

## Appendix: APDU Commands Reference

For debugging or custom implementations:

### Select eID Application

```
CLA: 00
INS: A4 (SELECT)
P1:  04 (Select by AID)
P2:  0C
Lc:  07
Data: A0 00 00 02 47 10 01 (ePassport/eID AID)
```

### Read Binary

```
CLA: 00
INS: B0 (READ BINARY)
P1:  Short file ID or offset high
P2:  Offset low
Le:  Number of bytes to read
```

### Verify PIN

```
CLA: 00
INS: 20 (VERIFY)
P1:  00
P2:  PIN reference (implementation specific)
Lc:  PIN length
Data: PIN bytes
```

### General Authenticate (PACE)

```
CLA: 00
INS: 86 (GENERAL AUTHENTICATE)
P1:  00
P2:  00
Lc:  Length
Data: Dynamic data for PACE steps
```

---

*Document created: January 2026*
*Based on research for cei-web-signer mobile extension*
