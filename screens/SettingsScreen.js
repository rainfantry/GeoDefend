import { useState } from "react";
import { ScrollView } from "react-native";
import { Text, TextInput } from "react-native-paper";

export default function SettingsScreen() {
  const [ip, setIp] = useState("192.168.1.92");

  return (
    <ScrollView style={{ flex: 1, backgroundColor: "#0a0a0a", padding: 20 }}>
      <Text
        variant="titleMedium"
        style={{ color: "#00ff41", marginBottom: 16 }}
      >
        Server Config
      </Text>

      <TextInput
        label="Scanner IP Address"
        value={ip}
        onChangeText={setIp}
        mode="outlined"
        style={{ marginBotton: 12 }}
        theme={{ colors: { primary: "#00ff41", background: "#1a1a1a" } }}
      />

      <Text variant="bodySmall" style={{ color: "#555" }}>
        http://{ip}:8765/WD_LPE_Latest.json
      </Text>
    </ScrollView>
  );
}
