# GeoDefend — Build Guide
**George Wu | Blue Team Mobile Dashboard | Expo SDK 54 + React Native Paper**

---

## What This Is

GeoDefend is a React Native mobile app that reads the output of `WD_LPE_Detect.ps1` and displays it on your phone. The PS1 runs on your Windows machine as Admin, writes a JSON file to Desktop, Python serves it over LAN, app fetches it.

```
PS1 (Admin) → WD_LPE_Latest.json → python -m http.server 8765 → phone app
```

---

## STEP 1 — Scaffold the Expo Project

Open terminal in your working directory and run:

```bash
npx create-expo-app GeoDefend
```

Then install dependencies:

```bash
npx expo install @react-navigation/native @react-navigation/bottom-tabs @react-navigation/native-stack
npx expo install react-native-screens react-native-safe-area-context
npx expo install react-native-paper react-native-vector-icons
```

---

## STEP 2 — Folder Structure

```
GeoDefend/
    App.js                 ← Navigation shell
    index.js               ← Entry point (you create this)
    package.json           ← Fix the "main" field
    screens/
        DashboardScreen.js ← Alert count, scan time, status
        FindingsScreen.js  ← Scrollable findings list grouped by level
        SettingsScreen.js  ← Server IP config
```

Create the `screens/` folder manually if it doesn't exist.

---

## STEP 3 — PS1 Modifications (WD_LPE_Detect.ps1)

The PS1 needs two additions to output JSON for the app.

### 3a — Add `$structured` array at the top (after `$alertcount = 0`)

```powershell
$structured = @()
```

### 3b — Add structured line to each Write function

Inside `Write-Alert` (after `$script:findings += $line`):
```powershell
$script:structured += [PSCustomObject]@{ level = $level; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
```

Inside `Write-Info`:
```powershell
$script:structured += [PSCustomObject]@{ level = "INFO"; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
```

Inside `Write-OK`:
```powershell
$script:structured += [PSCustomObject]@{ level = "OK"; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
```

### 3c — Add JSON output block ABOVE the ReadKey at the bottom

```powershell
# JSON output for GeoDefend mobile app
$jsonpath = "$env:USERPROFILE\Desktop\WD_LPE_Latest.json"
$payload = [PSCustomObject]@{
    timestamp  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    host       = $env:COMPUTERNAME
    user       = $env:USERNAME
    alertCount = $alertcount
    findings   = $structured
}
$payload | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonpath -Encoding UTF8
Write-Host "JSON saved to: $jsonpath" -ForegroundColor Cyan

# THIS MUST COME AFTER THE JSON BLOCK OR IT BLOCKS EXECUTION
Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
```

> ⚠️ ReadKey blocks everything after it. JSON block goes above it or it never runs.

---

## STEP 4 — Python Static File Server

Run the PS1 as Admin first to generate `WD_LPE_Latest.json` on Desktop. Then serve it:

```bash
cd C:\Users\<you>\Desktop
python -m http.server 8765
```

JSON is now live at:
```
http://<your-LAN-IP>:8765/WD_LPE_Latest.json
```

Find your LAN IP: `ipconfig` → look for `IPv4 Address` under your Wi-Fi adapter. Both machine and phone must be on the same network.

---

## STEP 5 — App.js (Bollerplate — nothing to learn here)

This is the navigation shell. Every React Native app with bottom tabs + stack nav looks like this. Copy it in, move on.

```javascript
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { Provider as PaperProvider } from "react-native-paper";

import DashboardScreen from "./screens/DashboardScreen";
import FindingsScreen from "./screens/FindingsScreen";
import SettingsScreen from "./screens/SettingsScreen";

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

function DashboardStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: "#0a0a0a" },
        headerTintColor: "#00ff41",
      }}
    >
      <Stack.Screen
        name="DashboardHome"
        component={DashboardScreen}
        options={{ title: "GeoDefend" }}
      />
      <Stack.Screen
        name="Findings"
        component={FindingsScreen}
        options={{ title: "Findings" }}
      />
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <PaperProvider>
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={{
            tabBarStyle: { backgroundColor: "#0a0a0a" },
            tabBarActiveTintColor: "#00ff41",
            tabBarInactiveTintColor: "#555",
            headerShown: false,
          }}
        >
          <Tab.Screen
            name="Dashboard"
            component={DashboardStack}
            options={{ headerShown: false }}
          />
          <Tab.Screen
            name="Settings"
            component={SettingsScreen}
            options={{
              headerStyle: { backgroundColor: "#0a0a0a" },
              headerTintColor: "#00ff41",
            }}
          />
        </Tab.Navigator>
      </NavigationContainer>
    </PaperProvider>
  );
}
```

---

## STEP 6 — DashboardScreen.js

This is the screen you write. It fetches the JSON and displays the alert count.

### Imports (top of file)

```javascript
import { useEffect, useState } from "react";
import { ScrollView } from "react-native";
import { Text } from "react-native-paper";
```

### Function signature + state variables

```javascript
export default function DashboardScreen({ navigation }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
```

### Server URL constant (replace IP with yours)

```javascript
  const SCAN_URL = "http://192.168.1.92:8765/WD_LPE_Latest.json";
```

### Fetch function

```javascript
  const loadScan = async () => {
    try {
      setLoading(true);
      const response = await fetch(SCAN_URL);
      const json = await response.json();
      setData(json);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };
```

### useEffect — runs loadScan on mount

```javascript
  useEffect(() => {
    loadScan();
  }, []);
```

### JSX return block

```javascript
  return (
    <ScrollView style={{ flex: 1, backgroundColor: "#0a0a0a", padding: 20 }}>
      <Text
        variant="headlineMedium"
        style={{ color: "#00ff41", fontWeight: "bold", marginBottom: 4 }}
      >
        GeoDefend
      </Text>

      <Text
        variant="displayLarge"
        style={{
          color: data?.alertCount > 0 ? "#ff4444" : "#00ff41",
          textAlign: "center",
          marginTop: 40,
        }}
      >
        {data?.alertCount ?? "-"}
      </Text>

      <Text
        variant="titleMedium"
        style={{ color: "#888", textAlign: "center", marginBottom: 40 }}
      >
        CRITICAL ALERTS
      </Text>
    </ScrollView>
  );
}
```

> ⚠️ Brace order matters. The `}` that closes the whole function goes **last** — after the `return (...)`. Not after useEffect.

---

## STEP 7 — Placeholder Screens (so Expo doesn't crash on mount)

**FindingsScreen.js**
```javascript
import { View } from "react-native";
import { Text } from "react-native-paper";

export default function FindingsScreen() {
  return (
    <View>
      <Text>Findings Coming Soon</Text>
    </View>
  );
}
```

**SettingsScreen.js**
```javascript
import { View } from "react-native";
import { Text } from "react-native-paper";

export default function SettingsScreen() {
  return (
    <View>
      <Text>Settings Coming Soon</Text>
    </View>
  );
}
```

---

## STEP 8 — index.js + package.json Fix

Expo SDK 54 defaults to Expo Router. It will ignore your App.js unless you redirect the entry point.

**Create `index.js` in project root:**
```javascript
import { registerRootComponent } from "expo";
import App from "./App";
registerRootComponent(App);
```

**In `package.json`, find:**
```json
"main": "expo-router/entry"
```

**Replace with:**
```json
"main": "index.js"
```

Also rename the `app/` folder to `app-backup/` so Expo Router doesn't pick it up.

---

## STEP 9 — Run It

```bash
npx expo start
```

Scan the QR code with Expo Go on your phone. Both devices need to be on the same Wi-Fi network as the Python server.

---

## Gotchas

| Problem | Fix |
|---------|-----|
| App shows Expo Router welcome screen | Check `package.json` main field + rename `app/` folder |
| JSON never gets written | ReadKey is above the JSON block — move it below |
| `import React` disappears on save | Use `{ useState, useEffect }` destructured imports instead |
| File blanks out on save | Turn off format-on-save: `"editor.formatOnSave": false` in VS Code settings |
| Fetch works in browser but not on phone | Use LAN IP not `localhost` — phone can't resolve your machine's localhost |
| PS1 self-destructs | `$jsonpath` pointed to the PS1 itself — double-check the path before running |

---

## CONTINUATION — Dashboard Button + FindingsScreen Build

### STEP A — Add Button + Loading indicator to DashboardScreen

In DashboardScreen.js, underneath the CRITICAL ALERTS `<Text>`, we add an ActivityIndicator (spinner while loading) and a Button that navigates to FindingsScreen.

The button uses `navigation.navigate("Findings"` — `"Findings"` is the screen name we defined in App.js Stack.Navigator. The second argument bundles `findings` and `alertCount` as a data parcel so FindingsScreen can pick them up via `route.params.findings`.

```javascript
{loading && (
  <ActivityIndicator color="#00ff41" style={{ marginTop: 20 }} />
)}

<Button
  mode="contained"
  buttonColor="#00ff41"
  textColor="#0a0a0a"
  style={{ marginTop: 20 }}
  onPress={() =>
    navigation.navigate("Findings", {
      findings: data?.findings,
      alertCount: data?.alertCount,
    })
  }
>
  VIEW FINDINGS
</Button>
```

Update imports at the top to include `Button` and `ActivityIndicator`:
```javascript
import { ActivityIndicator, Button, Text } from "react-native-paper";
```

---

### STEP B — Build FindingsScreen.js

For the findings screen we output the JSON but colour-code each alert to differentiate by category — ALERT, WARN, INFO, OK.

We import `Card` alongside `Text` so each alert has its own box. We import `ScrollView` to make the screen scrollable.

We address the possibility of no findings by using `findings = []` as a default — gives it an empty array if nothing comes through.

The `??` (nullish coalescing operator) on `route.params` handles the case where someone opens FindingsScreen without navigating from Dashboard — without it, destructuring `null` would crash.

`levelColor` is defined twice per card deliberately — once for the left border colour, once for the label text colour.

```javascript
import { ScrollView } from "react-native";
import { Card, Text } from "react-native-paper";

export default function FindingsScreen({ route }) {
  const { findings = [], alertCount } = route.params ?? {};

  const levelColor = (level) => {
    if (level === "ALERT") return "#ff4444";   // red
    if (level === "WARN")  return "#ffaa00";   // yellow
    if (level === "INFO")  return "#00aaff";   // blue
    return "#00ff41";                          // green (OK)
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: "#0a0a0a", padding: 16 }}>
      <Text variant="titleMedium" style={{ color: "#888", marginBottom: 16 }}>
        {alertCount} critical alert(s)
      </Text>

      {findings.map((item, index) => (
        <Card
          key={index}
          style={{
            marginBottom: 10,
            backgroundColor: "#1a1a1a",
            borderLeftWidth: 4,
            borderLeftColor: levelColor(item.level),
          }}
        >
          <Card.Content>
            <Text
              variant="labelSmall"
              style={{ color: levelColor(item.level), fontWeight: "bold" }}
            >
              {item.level} - {item.time}
            </Text>
            <Text
              variant="bodyMedium"
              style={{ color: "#e0e0e0", marginTop: 4 }}
            >
              {item.message}
            </Text>
          </Card.Content>
        </Card>
      ))}
    </ScrollView>
  );
}
```
