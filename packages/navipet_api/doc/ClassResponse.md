# navipet_api.model.ClassResponse

## Load the model package
```dart
import 'package:navipet_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**courseCode** | **String** |  | 
**courseName** | **String** |  | 
**building** | **String** | A CSULB building name or code (e.g. \"VEC\" or \"Vivian Engineering Center\") is resolved against the campus dataset. Anything else (a street address, another campus, an off-campus site) is forward-geocoded with Mapbox instead. Either way the stored class gets a resolved display name plus latitude/longitude. Required for in-person classes. Optional for online classes, where it is stored as sent (possibly empty) and never resolved. | 
**room** | **String** |  | 
**weekdays** | **List<int>** | ISO weekdays the class meets: 1 = Monday ... 7 = Sunday. | [default to const []]
**isOnline** | **bool** | An online class has no physical location: no building is required and no coordinates are stored. A synchronous online class still occupies its time slot for conflict checks. | 
**startTime** | **String** | 24-hour local time as stored, \"HH:MM:SS\". | 
**endTime** | **String** | 24-hour local time as stored, \"HH:MM:SS\". | 
**createdAt** | **String** |  | 
**updatedAt** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


