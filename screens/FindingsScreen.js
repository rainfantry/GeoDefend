import { useState } from "react";
import { ScrollView, View } from "react-native";
import { Card, Text, Chip } from "react-native-paper";

export default function FindingsScreen({ route }) {
  const { findings = [], alertCount } = route.params ?? {};
  const [filter, setFilter] = useState("ALL");

  const levelColor = (level) => {
    if (level === "ALERT") return "#ff4444";
    if (level === "WARN") return "#ffaa00";
    if (level === "INFO") return "#00aaff";
    return "#00ff41";
  };

  const category = (msg) => {
    if (/infostealer|marsalek|wallet|ghost\.ps1|svc\.py|r\.vbs|hd realtek|startup script|suspicious run key|hidden powershell/i.test(msg)) return "MALWARE";
    if (/defender|wd lpe|system-owned|recon|vss|definition/i.test(msg)) return "LPE";
    return "OTHER";
  };

  const filtered = findings.filter((item) => {
    if (filter === "ALL") return true;
    return category(item.message) === filter;
  });

  return (
    <ScrollView style={{ flex: 1, backgroundColor: "#0a0a0a", padding: 16 }}>
      <Text variant="titleMedium" style={{ color: "#888", marginBottom: 8 }}>
        {alertCount} total alert(s)
      </Text>

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
        {["ALL", "LPE", "MALWARE", "OTHER"].map((f) => (
          <Chip
            key={f}
            selected={filter === f}
            onPress={() => setFilter(f)}
            style={{ backgroundColor: filter === f ? "#00ff41" : "#1a1a1a" }}
            textStyle={{ color: filter === f ? "#0a0a0a" : "#e0e0e0" }}
          >
            {f}
          </Chip>
        ))}
      </View>

      {filtered.map((item, index) => (
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
              {category(item.message)} | {item.level} - {item.time}
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
