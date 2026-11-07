//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/accessibility_api.dart';
part 'api/authentication_api.dart';
part 'api/campus_api.dart';
part 'api/classes_api.dart';
part 'api/health_api.dart';
part 'api/profiles_api.dart';
part 'api/recent_searches_api.dart';

part 'model/auth_change_email_post202_response.dart';
part 'model/auth_change_email_post401_response.dart';
part 'model/auth_change_email_post422_response.dart';
part 'model/auth_change_email_post429_response.dart';
part 'model/auth_change_email_post_request.dart';
part 'model/auth_forgot_password_post200_response.dart';
part 'model/auth_forgot_password_post404_response.dart';
part 'model/auth_forgot_password_post422_response.dart';
part 'model/auth_forgot_password_post429_response.dart';
part 'model/auth_forgot_password_post502_response.dart';
part 'model/auth_forgot_password_post503_response.dart';
part 'model/auth_forgot_password_post_request.dart';
part 'model/auth_login_post200_response.dart';
part 'model/auth_login_post400_response.dart';
part 'model/auth_login_post400_response_error.dart';
part 'model/auth_login_post401_response.dart';
part 'model/auth_login_post403_response.dart';
part 'model/auth_login_post422_response.dart';
part 'model/auth_login_post429_response.dart';
part 'model/auth_login_post502_response.dart';
part 'model/auth_login_post_request.dart';
part 'model/auth_logout_all_post404_response.dart';
part 'model/auth_logout_all_post500_response.dart';
part 'model/auth_logout_post401_response.dart';
part 'model/auth_logout_post429_response.dart';
part 'model/auth_logout_post500_response.dart';
part 'model/auth_logout_post503_response.dart';
part 'model/auth_me_get200_response.dart';
part 'model/auth_me_get200_response_user.dart';
part 'model/auth_me_get403_response.dart';
part 'model/auth_me_get500_response.dart';
part 'model/auth_me_get503_response.dart';
part 'model/auth_refresh_post401_response.dart';
part 'model/auth_refresh_post422_response.dart';
part 'model/auth_refresh_post429_response.dart';
part 'model/auth_refresh_post500_response.dart';
part 'model/auth_refresh_post_request.dart';
part 'model/auth_register_post200_response.dart';
part 'model/auth_register_post409_response.dart';
part 'model/auth_register_post422_response.dart';
part 'model/auth_register_post429_response.dart';
part 'model/auth_register_post500_response.dart';
part 'model/auth_register_post_request.dart';
part 'model/auth_reset_password_post401_response.dart';
part 'model/auth_reset_password_post422_response.dart';
part 'model/auth_reset_password_post500_response.dart';
part 'model/auth_reset_password_post_request.dart';
part 'model/auth_verify_otp_post200_response.dart';
part 'model/auth_verify_otp_post401_response.dart';
part 'model/auth_verify_otp_post422_response.dart';
part 'model/auth_verify_otp_post429_response.dart';
part 'model/auth_verify_otp_post_request.dart';
part 'model/autocomplete_get200_response.dart';
part 'model/autocomplete_get200_response_proximity.dart';
part 'model/autocomplete_get200_response_results_inner.dart';
part 'model/autocomplete_get200_response_results_inner_navigation.dart';
part 'model/autocomplete_get200_response_results_inner_navigation_outdoor_destination.dart';
part 'model/autocomplete_get422_response.dart';
part 'model/autocomplete_get502_response.dart';
part 'model/buildings_building_code_rooms_get200_response.dart';
part 'model/buildings_building_code_rooms_get200_response_building.dart';
part 'model/buildings_building_code_rooms_get404_response.dart';
part 'model/buildings_building_code_rooms_get422_response.dart';
part 'model/class_response.dart';
part 'model/classes_class_id_delete404_response.dart';
part 'model/classes_class_id_patch200_response.dart';
part 'model/classes_class_id_patch404_response.dart';
part 'model/classes_class_id_patch_request.dart';
part 'model/classes_get200_response.dart';
part 'model/classes_get502_response.dart';
part 'model/classes_post201_response.dart';
part 'model/classes_post201_response_class.dart';
part 'model/classes_post404_response.dart';
part 'model/classes_post409_response.dart';
part 'model/classes_post409_response_error.dart';
part 'model/classes_post409_response_error_conflicts_inner.dart';
part 'model/classes_post_request.dart';
part 'model/health_get200_response.dart';
part 'model/places_place_id_get200_response.dart';
part 'model/places_place_id_get404_response.dart';
part 'model/places_place_id_get422_response.dart';
part 'model/profiles_me_accessibility_get200_response.dart';
part 'model/profiles_me_accessibility_get200_response_accessibility.dart';
part 'model/profiles_me_accessibility_get200_response_accessibility_guidance.dart';
part 'model/profiles_me_accessibility_get200_response_accessibility_mobility.dart';
part 'model/profiles_me_accessibility_get200_response_accessibility_visuals.dart';
part 'model/profiles_me_accessibility_get502_response.dart';
part 'model/profiles_me_accessibility_patch400_response.dart';
part 'model/profiles_me_accessibility_patch_request.dart';
part 'model/profiles_me_accessibility_patch_request_guidance.dart';
part 'model/profiles_me_accessibility_patch_request_mobility.dart';
part 'model/profiles_me_accessibility_patch_request_visuals.dart';
part 'model/profiles_me_avatar_post200_response.dart';
part 'model/profiles_me_avatar_post400_response.dart';
part 'model/profiles_me_avatar_post413_response.dart';
part 'model/profiles_me_avatar_post415_response.dart';
part 'model/profiles_me_avatar_upload_id_delete404_response.dart';
part 'model/profiles_me_avatar_upload_id_delete422_response.dart';
part 'model/profiles_me_avatar_upload_id_delete502_response.dart';
part 'model/profiles_me_avatar_upload_id_delete503_response.dart';
part 'model/profiles_me_get200_response.dart';
part 'model/profiles_me_get200_response_profile.dart';
part 'model/profiles_me_get404_response.dart';
part 'model/profiles_me_patch404_response.dart';
part 'model/profiles_me_patch422_response.dart';
part 'model/profiles_me_patch_request.dart';
part 'model/recent_searches_get200_response.dart';
part 'model/recent_searches_get200_response_recent_searches_inner.dart';
part 'model/recent_searches_get401_response.dart';
part 'model/recent_searches_get422_response.dart';
part 'model/recent_searches_get502_response.dart';
part 'model/recent_searches_post201_response.dart';
part 'model/recent_searches_post404_response.dart';
part 'model/recent_searches_post_request.dart';

/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) =>
    pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
