# iOS signing and APNs

The configured team signs the existing `com.rishthefish.kavach` app successfully. The baseline was installed and launched on the connected physical iPhone. Sign in with Apple and Push Notifications entitlements are not yet configured or verified.

The owner must enable both capabilities for the same registered App ID in Xcode Signing & Capabilities and obtain a matching provisioning profile. Confirm the final signed app's `aps-environment` matches Mac 2's provider environment/topic. Mac 2 exclusively stores the APNs private signing key; never transfer it to iOS.

After canonical device-registration contracts arrive: implement user-triggered permission, app-delegate token callbacks, authenticated registration after login, logout revocation and authorized alert fetching on notification taps. Tokens are variable-length opaque bytes and stay in memory until secure registration. Acceptance requires two identities and a real backgrounded receiving iPhone, APNs acceptance, observed notification and authorized navigation. No local notification or simulator injection substitutes for this proof.
