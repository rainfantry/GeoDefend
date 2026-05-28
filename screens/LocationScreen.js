import * as Location from "expo-location";
import { useEffect, useState } from "react";
import { StyleSheet, View } from "react-native";
import MapView from "react-native-maps";
import { Text } from "react-native-paper";

export default function LocationScreen() {
  const [location, setLocation] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);

  useEffect(() => {
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== "granted") {
        setErrorMsg("Location permission denied");
        return;
      }
      await Location.watchPositionAsync(
        { accuracy: Location.Accuracy.High },
        (pos) => setLocation(pos),
      );
    })();
  }, []);

  return (
    <View style={styles.container}>
      <MapView
        style={styles.map}
        showsUserLocation={true}
        followUserLocation={true}
        region={
          location
            ? {
                latitude: location.coords.latitude,
                longitude: location.coords.longitude,
                latitudeDelta: 0.005,
                longitudeDelta: 0.005,
              }
            : null
        }
      />
      <View style={styles.overlay}>
        <Text style={styles.coords}>
          {location
            ? `${location.coords.latitude.toFixed(5)}, ${location.coords.longitude.toFixed(5)}`
            : (errorMsg ?? "Acquiring signal...")}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0a0a0a" },
  map: { flex: 1 },
  overlay: {
    position: "absolute",
    bottom: 30,
    alignSelf: "center",
    backgroundColor: "rgba(0,0,0,0.7)",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#00ff41",
  },
  coords: { color: "#00ff41", fontFamily: "monospace", fontSize: 13 },
});
