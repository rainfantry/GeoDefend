import { useEffect, useState } from "react";
import { ScrollView } from "react-native";
import { ActivityIndicator, Button, Text } from "react-native-paper";

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
    </ScrollView>
  );
}
