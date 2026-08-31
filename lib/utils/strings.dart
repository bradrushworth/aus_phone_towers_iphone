class Strings {
  static String something_went_wrong = 'Oops something went wrong!';
  static String app_title = "Aus Phone Towers";
  static String telstra = "Telstra";
  static String optus = "Optus";
  static String vodafone = "Vodafone";
  static String dense_air = "Dense Air";
  static String nbn = "NBN";
  static String other = "Other";
  static String tv = "TV";
  static String radio = "Radio";
  static String cbrs = "CBRS";
  static String aviation = "Aviation";
  static String civil = "Civil";
  static String pager = "Pager";

  static String zoominFurther = "Zoom in further to download towers...";
  static String dismiss = "Dismiss";

  static String twoG_GSM = '2G GSM';
  static String threeG_UMTS = '3G UMTS';
  static String fourG_LTE = '4G LTE';
  static String fiveG_NR = '5G NR';

  static String multiplex_type = 'Multiplex Type';
  static String not_lte = 'NOT LTE';
  static String fd_lte = 'FD-LTE';
  static String td_lte = 'TD-LTE';

  static String frequencies = 'Frequencies';
  static String less_700 = '< 700 MHz';
  static String between700_1000 = '700 - 1000 MHz';
  static String between1_2 = '1.0 - 2.4 GHz';
  static String between2_3 = '2.4 - 3.8 GHz';
  static String greater_than_3 = '>= 3.8 GHz';

  static String radiation_models = 'Radiation Models';
  static String metropolitan = 'Metropolitan';
  static String urban = 'Urban';
  static String suburban = 'Suburban';
  static String open = 'Open';

  static String signal_strength = 'Signal Strength';
  static String maximum_signal = 'Maximum';
  static String strong_signal = 'Strong';
  static String good_signal = 'Good';
  static String weak_signal = 'Weak';

  static String transmitter_type = 'Transmitter Type';
  static String transmitter_type_telecommunication = 'Telecomunications';
  static String transmitter_type_radio = 'Radio';
  static String transmitter_type_tv = 'TV';
  static String transmitter_type_civil = 'Civil';
  static String transmitter_type_pager = 'Pager';
  static String transmitter_type_CBRS = 'CBRS';
  static String transmitter_type_aviation = 'Aviation';

  static String calculate_terrain = 'Calculate Terrain';
  static String follow_gps = 'Follow GPS';
  static String follow_gps_on = 'Disable Follow GPS';
  static String follow_gps_off = 'Follow GPS';
  static String rotating_map = 'Rotating Map';
  static String rotating_map_travel_direction = 'Travel Direction';
  static String rotating_map_phone_orientation = 'Phone Orientation';
  static String rotating_map_disable = 'Disable Rotation';
  static String hide_border = 'Hide Borders';
  static String show_border = 'Show Borders';
  static String lock_map = 'Lock Map';
  static String unlock_map = 'Unlock Map';
  static String search_sites = 'Search Sites';
  static String clear_map = 'Clear Map';
  static String clear_polygons = 'Clear Polygons';
  static String reload_everything = 'Refresh Data';

  static String map_mode = 'Map Mode';
  static String map_mode_terrain = 'Terrain';
  static String map_mode_hybrid = 'Hybrid';
  static String map_mode_satellite = 'Satellite';
  static String map_mode_normal = 'Normal';

  static String hiding_menu = 'Map Display';
  static String hiding_menu_hide_radiation = 'Hide Radiation on Click';
  static String hiding_menu_draw_radiation = 'Draw Radiation on Click';
  static String hiding_menu_multi_tower = 'Multi-Tower Coverage';
  static String disable_refarming = 'Disable frequency refarming';
  static String disable_refarming_summary =
      'When on, legacy 3G (UMTS) licences in bands now run as 4G/5G are shown at their current reuse (4G LTE).';

  static String polygon_precision = 'Polygon Precision';
  static String polygon_precision_low = 'Low (faster)';
  static String polygon_precision_medium = 'Medium';
  static String polygon_precision_high = 'High (smoother)';

  static String export_data = 'Export Data';
  // Overflow row shared with the Android app's popup_menu.xml. (userGuide and reportProblem are
  // declared further down, alongside the other Help strings.)
  static String settings = 'Settings';
  static String export_towers_geojson = 'Export Towers (GeoJSON)';
  static String export_towers_csv = 'Export Towers (CSV)';
  static String export_coverage_geojson = 'Export Coverage (GeoJSON)';

  static String problems_menu = 'Help & Feedback';

  static String remove_ads = 'Remove Ads';
  static String remove_ads_subscribe_previous =
      'You are subscribed! Thanking you.';
  // Product names, with NO price baked in — the live price is pulled from the store via
  // PurchaseHelper.priceLabel (see PriceLabelHelper) and appended at display time.
  //
  // There are deliberately no hardcoded-price fallback strings here any more. They used to read
  // 'One Year Ad Free (\$9.99)' and were shown verbatim whenever a SKU was missing from the store
  // response — so a product id that no longer matched App Store Connect, or a repricing, left the
  // app quoting a price the store would never charge. A name with no price is always honest; a
  // stale price is not. See PriceLabelHelper.buildLabel, which now falls back to the bare name.
  static String remove_ads_year_name = 'One Year Ad Free';
  static String remove_ads_permanent_name = 'Permanent Ad Free';
  static String subscribed_permanently = 'Permanently subscribed.';
  static String restore_purchases = 'Restore Purchases';

  static String donate = 'Donate';
  static String donatePrevious = 'Thanks for your previous donation!';
  // Product names, with no price baked in (see remove_ads_year_name above).
  static String donateSmallName = 'Morning Coffee';
  static String donateMediumName = 'Coffee and Cake';
  static String donateLargeName = 'Thanks For Lunch';
  static String donateSupportPrompt = 'Support the App';
  static String supportPromptRateHeader = 'Or just leave a rating';
  static String supportPromptRateAction = 'Rate the app';

  // Support the App screen (see lib/ui/widgets/support_prompt_screen.dart), ported from the
  // Java app's SupportPromptActivity.
  static String supportPromptTitle = 'Support Aus Phone Towers';
  static String supportPromptMessage =
      'This app is a hobby project and costs me about \$150 per month to keep it running. '
      'Thank you for your continued support!';
  static String supportPromptDonateHeader = 'Make a donation';
  static String supportPromptAdfreeHeader = 'Or remove the ads';
  static String supportPromptThanks = 'Thank you for your continued support!';
  static String supportPromptMaybeLater = 'Maybe later';

  static String developerMode = 'Developer Mode';
  static String regularMode = 'Regular Mode';

  static String reportProblem = 'Report a Problem';
  static String exportPolygons = 'Export Coverage';
  static String userGuide = 'User Guide';
  static String rateApp = 'Rate App';
  static String links = 'Links';
  static String ausphonetowers = 'AusPhoneTowers.com.au';
  static String iosAppStore = 'iOS App Store';
  static String androidPlayStore = 'Google Play (Android)';
  static String sourceCode = 'Source Code';
  static String closeApp = 'Close App';
}
