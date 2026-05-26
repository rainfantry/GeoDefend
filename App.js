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
