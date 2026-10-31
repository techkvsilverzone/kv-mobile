import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/features/contact/data/contact_repository.dart';
import 'package:kv_silver_mobile/features/contact/presentation/contact_screen.dart';

class _FakeContactRepository implements ContactRepository {
  final payloads = <Map<String, String>>[];
  ApiException? error;

  @override
  Future<void> sendEnquiry(Map<String, String> payload) async {
    payloads.add(payload);
    if (error != null) throw error!;
  }
}

void main() {
  late _FakeContactRepository repo;

  setUp(() => repo = _FakeContactRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [contactRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ContactScreen()),
    ));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Send Message');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(field('Full Name'), 'Vino');
    await tester.enterText(field('Email Address'), 'vino@example.com');
    await tester.enterText(field('Phone Number'), '+91 98765 43210');
    await tester.enterText(field('Message'), 'Do you make custom kavasam?');
  }

  testWidgets('an empty submit shows every field error and sends nothing', (tester) async {
    await pump(tester);

    await submit(tester);

    expect(find.text('Please enter at least 2 characters'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Please enter at least 10 characters'), findsOneWidget);
    expect(repo.payloads, isEmpty);
  });

  testWidgets('a valid submit sends the web payload, confirms and resets the form', (tester) async {
    await pump(tester);
    await fillValid(tester);
    final subject = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(subject);
    await tester.pumpAndSettle();
    await tester.tap(subject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order Inquiry').last);
    await tester.pumpAndSettle();

    await submit(tester);

    expect(repo.payloads, [
      {
        'name': 'Vino',
        'email': 'vino@example.com',
        'subject': 'order',
        'message': 'Do you make custom kavasam?',
      },
    ]);
    expect(find.text('Message Sent!'), findsOneWidget);
    expect(find.text('Our team will get back to you within 24 hours.'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('Full Name')).controller!.text, isEmpty);
    expect(find.text('Select a topic'), findsOneWidget);
  });

  testWidgets('no subject defaults to General Enquiry; a server error shows its message',
      (tester) async {
    repo.error = const ServerException(502, 'Failed to send message');
    await pump(tester);
    await fillValid(tester);

    await submit(tester);

    expect(repo.payloads.single['subject'], 'General Enquiry');
    expect(find.text('Message failed'), findsOneWidget);
    expect(find.text('Failed to send message'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('Full Name')).controller!.text, 'Vino');
  });
}
