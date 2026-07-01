import { useEffect, useState } from "react";
import { ScrollView, View } from "react-native";
import { ActivityIndicator, Button, Text, Chip } from "react-native-paper";

export default function DashboardScreen({ navigation }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);

  const SCAN_URL = "http://192.168.1.92:8765/WD_LPE_Latest.json";

  const loadScan = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${SCAN_URL}?t=${Date.now()}`);
      const json = await response.json();
      setData(json);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => {
    loadScan();
  }, []);

  // Categorise findings by keyword
  const lpeAlerts = data?.findings?.filter((f) =>
    /defender|wd lpe|system-owned|recon|vss|definition/i.test(f.message)
  ) || [];
  const malwareAlerts = data?.findings?.filter((f) =>
    /infostealer|marsalek|wallet|ghost\.ps1|svc\.py|r\.vbs|hd realtek|startup script|suspicious run key|hidden powershell/i.test(f.message)
  ) || [];

  return (
    <ScrollView style={{ flex: 1, backgroundColor: "#0a0a0a", padding: 20 }}>
      <Text
        variant="headlineMedium"
        style={{ color: "#00ff41", fontWeight: "bold", marginBottom: 4 }}
      >
        GeoDefend
      </Text>

      <Text
        variant="titleMedium"
        style={{ color: "#888", textAlign: "center", marginBottom: 20 }}
      >
        {data?.host ?? "-"} | {data?.timestamp?.split("T")[0] ?? ""}
      </Text>

      <Text
        variant="displayLarge"
        style={{
          color: data?.alertCount > 0 ? "#ff4444" : "#00ff41",
          textAlign: "center",
          marginTop: 10,
        }}
      >
        {data?.alertCount ?? "-"}
      </Text>

      <Text
        variant="titleMedium"
        style={{ color: "#888", textAlign: "center", marginBottom: 20 }}
      >
        TOTAL ALERTS
      </Text>

      <View style={{ flexDirection: "row", justifyContent: "center", gap: 10, marginBottom: 20 }}>
        <Chip style={{ backgroundColor: "#1a1a1a" }} textStyle={{ color: lpeAlerts.length ? "#ffaa00" : "#00ff41" }}>
          WD LPE: {lpeAlerts.length}
        </Chip>
        <Chip style={{ backgroundColor: "#1a1a1a" }} textStyle={{ color: malwareAlerts.length ? "#ff4444" : "#00ff41" }}>
          Malware: {malwareAlerts.length}
        </Chip>
      </View>

      {loading && (
        <ActivityIndicator color="#00ff41" style={{ marginTop: 20 }} />
      )}

      <Button
        mode="contained"
        buttonColor="#00ff41"
        textColor="#0a0a0a"
        style={{ marginTop: 10 }}
        onPress={() =>
          navigation.navigate("Findings", {
            findings: data?.findings,
            alertCount: data?.alertCount,
          })
        }
      >
        VIEW ALL FINDINGS
      </Button>
    </ScrollView>
  );
}
