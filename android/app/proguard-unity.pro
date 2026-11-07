# Unity loads Java classes and members by name from native code/C#.
# Includes com.unity3d.plugin.UnityAndroidPermissions and its callbacks.
-keep class com.unity3d.** { *; }

# IndoorArBridge calls deliverResult by name from C#.
-keep class com.navipet.navipet.UnityHostActivity { *; }
