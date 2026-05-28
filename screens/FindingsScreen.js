import { ScrollView } from "react-native";
import { Card, Text } from "react-native-paper";

export default function FindingsScreen({ route }) {
  const { findings = [], alertCount } = route.params ?? {};

  const levelColor = (level) => {
    if (level === "ALERT") return "#ff4444";
    if (level === "WARN") return "#ffaa00";
    if (level === "INFO") return "#00aaff";
    return "#00ff41";
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
