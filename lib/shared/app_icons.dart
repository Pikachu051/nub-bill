import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Centralized icon mapping for the Nub Bill app.
/// All screens/widgets should import this instead of using raw LucideIcons or Icons.
/// This makes it trivial to swap individual icons across the entire app.
abstract final class AppIcons {
  // ── Navigation / Tabs ──
  static const IconData home = LucideIcons.house;
  static const IconData groups = LucideIcons.users;
  static const IconData friends = LucideIcons.user;
  static const IconData notifications = LucideIcons.bell;
  static const IconData notificationsActive = LucideIcons.bellRing;
  static const IconData profile = LucideIcons.user;

  // ── Common Actions ──
  static const IconData close = LucideIcons.x;
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData check = LucideIcons.check;
  static const IconData checkCircle = LucideIcons.circleCheckBig;
  static const IconData checkCircleFilled = LucideIcons.circleCheck;
  static const IconData circleUnchecked = LucideIcons.circle;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData settings = LucideIcons.settings;
  static const IconData tune = LucideIcons.slidersHorizontal;
  static const IconData logout = LucideIcons.logOut;
  static const IconData help = LucideIcons.circleQuestionMark;

  // ── Navigation Arrows ──
  static const IconData arrowBack = LucideIcons.arrowLeft;
  static const IconData arrowUp = LucideIcons.arrowUp;
  static const IconData arrowDown = LucideIcons.arrowDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData chevronDown = LucideIcons.chevronDown;

  // ── People ──
  static const IconData people = LucideIcons.users;
  static const IconData person = LucideIcons.user;
  static const IconData personAdd = LucideIcons.userPlus;
  static const IconData personOff = LucideIcons.userX;

  // ── Media / Camera ──
  static const IconData camera = LucideIcons.camera;
  static const IconData photoLibrary = LucideIcons.images;
  static const IconData image = LucideIcons.image;
  static const IconData imagePlus = LucideIcons.imagePlus;
  static const IconData imageOff = LucideIcons.imageOff;

  // ── QR / Sharing ──
  static const IconData qrCode = LucideIcons.qrCode;
  static const IconData qrScanner = LucideIcons.scanLine;
  static const IconData link = LucideIcons.link;
  static const IconData share = LucideIcons.share;
  static const IconData download = LucideIcons.download;
  static const IconData paperclip = LucideIcons.paperclip;
  static const IconData copy = LucideIcons.copy;
  static const IconData badgeCheck = LucideIcons.badgeCheck;

  // ── Finance ──
  static const IconData receipt = LucideIcons.receipt;
  static const IconData creditCard = LucideIcons.creditCard;
  static const IconData bank = LucideIcons.landmark;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData money = LucideIcons.circleDollarSign;
  static const IconData barChart = LucideIcons.chartBar;

  // ── Category / Trip ──
  static const IconData flight = LucideIcons.plane;
  static const IconData flightTakeoff = LucideIcons.planeTakeoff;
  static const IconData hotel = LucideIcons.hotel;
  static const IconData restaurant = LucideIcons.utensilsCrossed;
  static const IconData favorite = LucideIcons.heart;
  static const IconData category = LucideIcons.layoutGrid;
  static const IconData car = LucideIcons.car;
  static const IconData fuel = LucideIcons.fuel;
  static const IconData localGasStation = LucideIcons.fuel;

  // ── Status / Feedback ──
  static const IconData error = LucideIcons.circleAlert;
  static const IconData errorOutline = LucideIcons.circleAlert;
  static const IconData visibility = LucideIcons.eye;
  static const IconData visibilityOff = LucideIcons.eyeOff;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData hourglass = LucideIcons.hourglass;
  static const IconData hourglassTop = LucideIcons.hourglass;
  static const IconData circle = LucideIcons.circle;

  // ── Misc ──
  static const IconData calendar = LucideIcons.calendar;
  static const IconData description = LucideIcons.fileText;
  static const IconData mail = LucideIcons.mail;
  static const IconData mailCheck = LucideIcons.mailCheck;
}
