import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/validation/validators.dart';
import '../application/address_controller.dart';
import '../data/models/address.dart';
import 'widgets/code_field.dart' show buttonSpinner;
import 'widgets/form_error_banner.dart';

/// Add or edit an address. Pass an [Address] to edit; omit it to create.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});

  final Address? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _phone;

  late bool _isDefault;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _label = TextEditingController(text: a?.label ?? '');
    _firstName = TextEditingController(text: a?.firstName ?? '');
    _lastName = TextEditingController(text: a?.lastName ?? '');
    _address = TextEditingController(text: a?.address ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _state = TextEditingController(text: a?.state ?? '');
    _pincode = TextEditingController(text: a?.pincode ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final c in [_label, _firstName, _lastName, _address, _city, _state, _pincode, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    // The server's regex is strict (`^[6-9]\d{9}$` — no +91, no spaces), while
    // our validator accepts the friendlier forms the web allows. Normalize
    // before sending or a perfectly valid entry gets rejected.
    final address = Address(
      id: widget.existing?.id ?? '',
      label: _label.text.trim(),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      phone: normalizePhone(_phone.text),
      isDefault: _isDefault,
    );

    try {
      final controller = ref.read(addressListProvider.notifier);
      if (_isEditing) {
        await controller.update(widget.existing!.id, address);
      } else {
        await controller.add(address);
      }
      if (!mounted) return;
      showKvToast(context, _isEditing ? 'Address updated' : 'Address saved');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _caption(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Kv.muted)),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    const words = TextCapitalization.words;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit address' : 'New address')),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? buttonSpinner : Text(_isEditing ? 'Save changes' : 'Save address'),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(Kv.pad),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null) ...[
              FormErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            _caption('Contact'),
            KvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      enabled: !_busy,
                      textCapitalization: words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'First name'),
                      validator: validateName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      enabled: !_busy,
                      textCapitalization: words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      // Deliberately laxer than first name — matches the web,
                      // where single-letter surnames are common.
                      validator: validateLastName,
                    ),
                  ),
                ]),
                gap,
                TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    prefixText: '+91  ',
                  ),
                  validator: validatePhone,
                ),
              ]),
            ),
            const SizedBox(height: Kv.gap),
            _caption('Address'),
            KvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _pincode,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'PIN code', counterText: ''),
                  validator: validatePincode,
                ),
                gap,
                TextFormField(
                  controller: _address,
                  enabled: !_busy,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'House no., street, area',
                    hintText: 'House / flat, street, landmark',
                    alignLabelWithHint: true,
                  ),
                  validator: validateStreetAddress,
                ),
                gap,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      enabled: !_busy,
                      textCapitalization: words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: validateCity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _state,
                      enabled: !_busy,
                      textCapitalization: words,
                      decoration: const InputDecoration(labelText: 'State'),
                      validator: validateState,
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: Kv.gap),
            _caption('Save as'),
            KvCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _label,
                    enabled: !_busy,
                    textCapitalization: words,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      hintText: 'Home, Office…',
                      prefixIcon: Icon(Icons.bookmark_border_rounded),
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: _busy ? null : (v) => setState(() => _isDefault = v),
                  title: const Text('Default address'),
                  subtitle: const Text('Used first at checkout'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
