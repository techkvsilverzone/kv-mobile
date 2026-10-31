import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/widgets/not_found_screen.dart';
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/auth/presentation/address_book_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/address_form_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/change_password_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/phone_verification_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/profile_screen.dart';
import 'package:kv_silver_mobile/features/auth/presentation/signup_screen.dart';
import 'package:kv_silver_mobile/features/contact/presentation/contact_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/about_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/faq_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/privacy_policy_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/terms_screen.dart';
import 'package:kv_silver_mobile/features/notifications/notifications.dart';
import 'package:kv_silver_mobile/features/notifications/notifications_screen.dart';
import '../test/support/fake_auth_repository.dart';
import 'account_fixtures.dart';
import 'screenshot.dart';

void main() {
  final user = [currentUserProvider.overrideWithValue(sampleUser())];
  final auth = [authRepositoryProvider.overrideWithValue(FakeAuthRepository())];
  List<Override> addresses(List<Address>? a) => [addressRepositoryProvider.overrideWithValue(FakeAddressRepository(a))];
  List<Override> inbox(Future<NotificationInbox> Function() f) => [notificationInboxProvider.overrideWith((ref) => f())];

  // Auth
  testWidgets('signup', (t) => screenshot(t, 'acc_signup', const SignupScreen()));
  testWidgets('signup stall', (t) => screenshot(t, 'acc_signup_stall', const SignupScreen(stallLink: true),
      overrides: [stallActiveProvider.overrideWith((ref) async => true)]));
  testWidgets('signup errors', (t) => screenshot(t, 'acc_signup_errors', const SignupScreen(), before: (t) async {
        await t.tap(find.text('Create account'));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('forgot', (t) => screenshot(t, 'acc_forgot', const ForgotPasswordScreen(), overrides: auth));
  testWidgets('forgot reset', (t) => screenshot(t, 'acc_forgot_reset', const ForgotPasswordScreen(), overrides: auth,
          before: (t) async {
        await t.enterText(find.byType(TextFormField), 'vinoth.kumar@example.com');
        await t.tap(find.text('Send reset code'));
        await t.pump();
        await t.pump(const Duration(seconds: 4)); // let the toast go
      }));
  testWidgets('verify phone', (t) => screenshot(t, 'acc_verify_phone',
      const PhoneVerificationScreen(codeAlreadySent: true), overrides: user));

  // Account sub-pages
  testWidgets('profile', (t) => screenshot(t, 'acc_profile', const ProfileScreen(), overrides: user));
  testWidgets('profile verified', (t) => screenshot(t, 'acc_profile_verified', const ProfileScreen(),
      overrides: [currentUserProvider.overrideWithValue(sampleUser(verified: true))]));
  testWidgets('addresses', (t) => screenshot(t, 'acc_addresses', const AddressBookScreen(),
      overrides: addresses(sampleAddresses)));
  testWidgets('addresses menu', (t) => screenshot(t, 'acc_addresses_menu', const AddressBookScreen(),
          overrides: addresses(sampleAddresses), before: (t) async {
        await t.tap(find.byTooltip('Address options').at(1));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('addresses empty', (t) => screenshot(t, 'acc_addresses_empty', const AddressBookScreen(),
      overrides: addresses(const [])));
  testWidgets('addresses loading', (t) => screenshot(t, 'acc_addresses_loading', const AddressBookScreen(),
      overrides: addresses(null)));
  testWidgets('address new', (t) => screenshot(t, 'acc_address_new', const AddressFormScreen()));
  testWidgets('address edit', (t) => screenshot(t, 'acc_address_edit', AddressFormScreen(existing: sampleAddresses[1])));
  testWidgets('address edit scrolled', (t) => screenshot(t, 'acc_address_edit_scrolled',
      AddressFormScreen(existing: sampleAddresses[1]), scroll: 400));
  testWidgets('change password', (t) => screenshot(t, 'acc_change_password', const ChangePasswordScreen()));

  // Notifications
  testWidgets('notifications', (t) => screenshot(t, 'acc_notifications', const NotificationsScreen(),
      overrides: inbox(() async => sampleInbox())));
  testWidgets('notifications empty', (t) => screenshot(t, 'acc_notifications_empty', const NotificationsScreen(),
      overrides: inbox(() async => const NotificationInbox())));
  testWidgets('notifications loading', (t) => screenshot(t, 'acc_notifications_loading', const NotificationsScreen(),
      overrides: inbox(() => Completer<NotificationInbox>().future)));

  // Info
  testWidgets('about', (t) => screenshot(t, 'acc_about', const AboutScreen()));
  testWidgets('about 2', (t) => screenshot(t, 'acc_about_2', const AboutScreen(), scroll: 650));
  testWidgets('about 3', (t) => screenshot(t, 'acc_about_3', const AboutScreen(), scroll: 1400));
  testWidgets('about 4', (t) => screenshot(t, 'acc_about_4', const AboutScreen(), scroll: 2400));
  testWidgets('faq', (t) => screenshot(t, 'acc_faq', const FaqScreen(), before: (t) async {
        await t.tap(find.text('What is BIS Hallmarking?'));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('faq bottom', (t) => screenshot(t, 'acc_faq_bottom', const FaqScreen(), scroll: 600));
  testWidgets('privacy', (t) => screenshot(t, 'acc_privacy', const PrivacyPolicyScreen()));
  testWidgets('terms', (t) => screenshot(t, 'acc_terms', const TermsScreen(), scroll: 500));
  testWidgets('contact', (t) => screenshot(t, 'acc_contact', const ContactScreen()));
  testWidgets('contact scrolled', (t) => screenshot(t, 'acc_contact_scrolled', const ContactScreen(), scroll: 600));
  testWidgets('not found', (t) => screenshot(t, 'acc_not_found', const NotFoundScreen()));
}
