# navipet_api.model.ClassesClassIdPatchRequest

## Load the model package
```dart
import 'package:navipet_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**courseCode** | **String** |  | [optional] 
**courseName** | **String** |  | [optional] 
**building** | **String** | A CSULB building name or code (e.g. \"VEC\" or \"Vivian Engineering Center\") is resolved against the campus dataset. Anything else (a street address, another campus, an off-campus site) is forward-geocoded with Mapbox instead. Either way the stored class gets a resolved display name plus latitude/longitude. Required for in-person classes. Optional for online classes, where it is stored as sent (possibly empty) and never resolved. | [optional] 
**room** | **String** |  | [optional] 
**weekdays** | **List<int>** | ISO weekdays the class meets: 1 = Monday ... 7 = Sunday. | [optional] [default to const []]
**isOnline** | **bool** | An online class has no physical location: no building is required and no coordinates are stored. A synchronous online class still occupies its time slot for conflict checks. | [optional] 
**startTime** | **String** | Local start time: 24-hour \"HH:MM\" / \"HH:MM:SS\", or 12-hour \"4:00 PM\" / \"4PM\". Omit when sending `time`. | [optional] 
**endTime** | **String** | Local end time, same formats as `startTime`. Must be later than `startTime`. Omit when sending `time`. | [optional] 
**time** | **String** | A CSULB schedule time range such as \"8-8:50AM\", \"12:30-3:15PM\", \"4-6:45PM\", or \"10:30AM-1:15PM\". AM/PM written once applies to both ends unless the range crosses noon (\"11-12:15PM\" is 11:00 AM-12:15 PM). Replaces `startTime` + `endTime`. \"NA/NA\" (no scheduled time) is rejected with 422. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


